#lang racket/base

(require racket/contract
         (only-in racket/port
                  port->bytes
                  port->string
                  read-bytes-evt)
         (only-in racket/unsafe/ops
                  unsafe-string-ref
                  unsafe-vector-ref))

(provide
 (contract-out
  [base32-decode (->* (input-port?)
                      (#:close? boolean?)
                      input-port?)]
  [base32-decode-bytes (-> base32? bytes?)]
  [base32-encode (->* (input-port?)
                      (#:close? boolean?)
                      input-port?)]
  [base32-encode-bytes (-> bytes? base32?)]
  [base32=? (-> base32? base32? boolean?)]
  [base32<? (-> base32? base32? boolean?)]))

;;
;; Contracts
;;

(define (base32-char? ch)
  (and (char? ch)
       (with-handlers ([exn:fail:contract? (lambda (_) #f)])
         (decode-ref (char->integer (base32-normalize-char ch)))
         #t)))

(define (base32? str)
  (and (string? str)
       (for/and ([ch (in-string str)])
         (base32-char? ch))))

;;
;; Operations on fixed Bytes/Strings
;;

(define (base32-encode-bytes bs)
  (port->string
   (base32-encode (open-input-bytes bs))))

(define (base32-decode-bytes b32)
  (port->bytes
   (base32-decode (open-input-string b32))))

;;
;; Equality & Ordering
;;

(define (base32=? a b)
  (equal? (base32-normalize-string a)
          (base32-normalize-string b)))

(define (base32<? a b)
  (string<? (base32-normalize-string a)
            (base32-normalize-string b)))

;;
;; Port operations
;;

(define (base32-encode input-port #:close? [close? #t])
  (make-input-port
   'encode-base32-input
   (lambda (mut-bytes)
     (let* ([evt (read-bytes-evt 5 input-port)]
            [chunk (sync/timeout 0 evt)])
       (cond
         [(eq? chunk eof) eof]
         [(eq? chunk #f) evt]
         [else (base32-encode-chunk chunk mut-bytes)])))
   ;; disable peeking
   #f
   ;; forward close to the provided input-port
   (lambda ()
     (when close?
       (close-input-port input-port)))))

(define (base32-decode input-port #:close? [close? #t])
  (make-input-port
   'decode-base32-input
   (lambda (mut-bytes)
     (let* ([evt (read-bytes-evt 8 input-port)]
            [chunk (sync/timeout 0 evt)])
       (cond
         [(eq? chunk eof) eof]
         [(eq? chunk #f) evt]
         [else (base32-decode-chunk chunk mut-bytes)])))
   ;; no peeking!
   #f
   ;; forward close to the provided input port
   (lambda ()
     (when close?
       (close-input-port input-port)))))

;;
;; Chunked operations
;;

(define (base32-encode-chunk chunk mut-bytes)
  (let* ([len (bytes-length chunk)]
         [emit-len (ceiling (/ (* 8 len) 5))]
         [chunk* (bytes-append #"\0\0\0" chunk (make-bytes (- 5 len)))])
    (for/fold ([acc (integer-bytes->integer chunk* #f #t)])
              ([idx (in-range 7 -1 -1)])
      (let-values ([(quot rem) (quotient/remainder acc 32)])
        (bytes-set! mut-bytes idx (encode-ref rem))
        quot))
    emit-len))

(define (base32-decode-chunk chunk mut-bytes)
  (let* ([emit-len (or (decoded-chunk-length chunk)
                       (raise-argument-error 'decode-chunk
                                             "(>/c 1 (bytes-length))"
                                             chunk))]
         [chunk-len (bytes-length chunk)]
         [offset (- 8 emit-len)]
         [chunk (bytes-append chunk (make-bytes (- 8 chunk-len) (char->integer #\=)))]
         [decoded (for/fold ([acc 0])
                            ([byte (in-bytes chunk)])
                    (+ (arithmetic-shift acc 5)
                       (or (vector-ref decoding-key byte)
                           (raise-argument-error 'base32-chunk->chunk
                                                 "(base32-char? (integer->char byte))"
                                                 (integer->char byte)))))])
    (for ([idx (in-range -3 5)]
          [byte (in-bytes (integer->integer-bytes decoded 8 #f #t))])
      (unless (< idx 0)
        (bytes-set! mut-bytes idx byte)))
    emit-len))

(define (decoded-chunk-length x)
  (let ([emit-size (floor (/ (* 5 (bytes-length x)) 8))])
    (and (> emit-size 0)
         emit-size)))

;;
;; Encoding and decoding base operations
;;

(define-values (encoding-key decoding-key)
  (let ([key #(#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9
               #\a #\b #\c #\d #\e #\f #\g #\h
               #\j #\k
               #\m #\n
               #\p #\q #\r #\s #\t
               #\v #\w #\x #\y #\z)]
        [encoding-key-mut (make-vector 32 0)]
        [decoding-key-mut (make-vector 128 #f)])
    (for ([ch (in-vector key)]
          [ix (in-naturals)])
      (let ([byte (char->integer ch)])
        (vector-set! encoding-key-mut ix byte)
        (vector-set! decoding-key-mut byte ix)))
    (vector-set! decoding-key-mut (char->integer #\=) 0)
    (values (vector->immutable-vector encoding-key-mut)
            (vector->immutable-vector decoding-key-mut))))

(define (encode-ref n)
  (if (and (<= 0 n) (< n 32))
      (unsafe-vector-ref encoding-key n)
      (raise-argument-error 'encode-ref
                            "(and/c (>=/c 0) (</c 32))"
                            n)))

(define (decode-ref n)
  (or (vector-ref decoding-key n)
      (raise-argument-error 'decode-ref
                            "base32-char-byte?"
                            n)))

(define (base32-normalize-string str)
  (build-string (string-length str)
                (lambda (idx)
                  (base32-normalize-char
                   (unsafe-string-ref str idx)))))

(define (base32-normalize-char ch)
  (case ch
    [(#\= #\O #\o) #\0]
    [(#\L #\I #\l #\i) #\1]
    [else (char-downcase ch)]))

(module+ test
  (require rackunit
           rackunit/text-ui)

  (define-test-suite base32-tests
    (with-conversion base32-encode-bytes
      (#"" "")
      (#"hello world" "d1jprv3f41vpywkccg")
      ((string->bytes/utf-8 "ünîcødé") "rey6xgxecf1vgs63n4")
      ((string->bytes/latin-1 "ünîcødé") "zhqewrzrckmg"))
    (with-conversion base32-decode-bytes
      ("" #"")
      ("d1jprv3f41vpywkccg" #"hello world")
      ("rey6xgxecf1vgs63n4" (string->bytes/utf-8 "ünîcødé"))
      ("zhqewrzrckmg" (string->bytes/latin-1 "ünîcødé")))
    (test-suite
     "base32-equal?"
     (check-base32-equal? "abcde" "ABCDE")
     (check-base32-equal? "0oO" "000")
     (check-base32-equal? "1iIlL" "11111")))

  (define-syntax-rule (with-conversion proc (input expected) ...)
    (begin
      (test-case (format "~s" '(proc input))
        (check-conversion proc input expected)) ...))

  (define-check (check-conversion proc input expected)
    (let ([actual (proc input)])
      (unless (equal? actual expected)
        (with-check-info (('input input)
                          ('expected expected)
                          ('actual actual))
          (fail-check
           (format "unexpected output of conversion via ~a"
                   (quote proc)))))))

  (define-simple-check (check-base32-equal? a b)
    (base32=? a b))

  (void (run-tests base32-tests)))

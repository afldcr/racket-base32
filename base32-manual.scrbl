#lang scribble/manual
@(require scribble/example
          racket/sandbox
          (for-label racket/base
                     racket/contract
                     base32))

@(define evaluator
   (parameterize ([sandbox-output 'string]
                  [sandbox-error-output 'string])
    (make-evaluator 'racket/base
                    #:requires '(base32))))

@title{Base32}
@author[@author+email["James Alexander Feldman-Crough" "alex@fldcr.com"]]

This library provides utilities for converting byte-strings to and from an
encoding based on
@hyperlink["https://www.crockford.com/wrmg/base32.html"]{Crockford's Base32
encoding}.

Compared to similar Base32 encodings like
@hyperlink["https://tools.ietf.org/html/rfc4648"]{RFC 4648}, Crockford's
encoding has a few desirable characteristics which make it especially
appealing for user-facing use:

@itemlist[(list @item{Potentially ambiguous characters, like @tt{i}, @tt{I},
                      @tt{l}, and @tt{L} are treated as synonyms.}
                @item{The digits @tt{0} through @tt{F} have the same value as
                      their hexadecimal counterparts.}
                @item{The letter @tt{U} is invalid, lowering the surface area
                      for obscene encodings.})]

This library deviates from Crockford's encoding by encoding strings as
lower-case by default. Hyphens are also disallowed as spacing and check
characters are unimplemented, although this is a shortcoming of the
implementation.

@section{API}
@defmodule[base32]

@subsection{Encoding and decoding byte-strings}

@defproc[(base32? [x any/c]) boolean?]{
  Determines whether or not a value is a valid Base32 encoding.
}

@defproc[(base32-decode-bytes [b32 base32?]) bytes?]{
  Encodes @racket[bs] as a base32 encoded string.
}

@defproc[(base32-encode-bytes [bs bytes?]) base32?]{
  Encodes @racket[bs] as a base32 encoded string.
}

@subsection{Encoding and decoding ports}

@defproc[(base32-decode [in input-port?]
                        [#:close? close? boolean? #t])
         input-port?]{
  Create a new input port that reads bytes from @racket[in] after decoding
  them. If @racket[in] is not base32 encoded, @racket[read] will raise an
  @racket[exn:fail:contract] upon encountering an invalid character.

  If @racket[close?] is @racket[#t], @racket[in] will be closed once
  @racket[eof] is reached.
}

@defproc[(base32-encode [in input-port?]
                        [#:close? close? boolean? #t])
         input-port?]{
  Create a new input port that reads base64-encoded bytes from @racket[in].

  If @racket[close?] is @racket[#t], @racket[in] will be closed once
  @racket[eof] is reached.
}

@subsection{Comparing base32 strings}

Because some characters are synonymous, two Base32 encodings may be
representationally equivalent but not structurally equivalent.

@examples[#:eval evaluator
  (define-values (x y)
    (values "ABC0123"
            "abcoi23"))
  (equal? x y)
  (base32=? x y)
  (string<? x y)
  (base32<? x y)
]

@defproc[(base32=? [x base32?] [y base32?]) boolean?]{
  Determine if two base32 strings are equivalent after normalizing synonymous
  characters.
}

@defproc[(base32<? [x base32?] [y base32?]) boolean?]{
  Determine if two base32 strings are ordered lexicographically after
  normalizing synonymous characters.
}

@section{Conversion table}

The following table shows the decimal value for each valid base32
character. When encoding, this library always chooses the first base32
representation in the table below.

@tabular[#:style 'boxed
         #:column-properties '(center center)
         #:row-properties '(bottom-border ())

  (cons (list @bold{base 10} @bold{base 32})
        '(("0" "0 o O =")
          ("1" "1 i I l L")
          ("2" "2")
          ("3" "3")
          ("4" "4")
          ("5" "5")
          ("6" "6")
          ("7" "7")
          ("8" "8")
          ("9" "9")
          ("10" "a A")
          ("11" "b B")
          ("12" "c C")
          ("13" "d D")
          ("14" "e E")
          ("15" "f F")
          ("16" "g G")
          ("17" "h H")
          ("18" "j J")
          ("19" "k K")
          ("20" "m M")
          ("21" "n N")
          ("22" "p P")
          ("23" "q Q")
          ("24" "r R")
          ("25" "s S")
          ("26" "t T")
          ("27" "v V")
          ("28" "w W")
          ("29" "x X")
          ("30" "y Y")
          ("31" "z Z")))
]

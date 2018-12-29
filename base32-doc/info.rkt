#lang info

(define collection
  "base32")

(define version
  "0.2")

(define deps
  '("base"))

(define build-deps
  '("scribble-lib"
    "base32-lib"
    "racket-doc"))

(define scribblings
  '(("base32.scrbl" ())))

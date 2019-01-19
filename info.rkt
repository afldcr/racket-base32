#lang info

(define collection
  "base32")

(define version
  "0.3.1")

(define deps
  '("base"))

(define build-deps
  '("racket-doc"
    "rackunit"
    "sandbox-lib"
    "scribble-lib"))

(define scribblings
  '(("base32-manual.scrbl" ())))

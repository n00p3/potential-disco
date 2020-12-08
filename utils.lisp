(defpackage #:utils
  (:use #:cl)
  (:export #:timings))

(in-package #:utils)

(defun timings (function)
  (let ((real-base (get-internal-real-time))
        (run-base (get-internal-run-time)))
    (funcall function)
    (values (/ (- (get-internal-real-time) real-base) internal-time-units-per-second)
            (/ (- (get-internal-run-time) run-base) internal-time-units-per-second))))
 

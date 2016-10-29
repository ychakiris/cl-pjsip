;;;; cl-pjsip.asd

(asdf:defsystem #:cl-pjsip
  :description "Common Lisp wrapper for PJSIP library"
  :author "Eugene Zaikonnikov <eugene@funcall.org>"
  :license "GPL v2"
  :version "0.1"
  :depends-on (#:cffi #:cffi-libffi)
  :serial t
  :components ((:file "package")
               (:file "cl-pjsip")
	       (:file "media-ports")))


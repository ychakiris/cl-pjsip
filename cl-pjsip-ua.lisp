(in-package #:cl-pjsip)

(defconstant +sip-port+ 5060)
(defconstant +rtp-port+ 4000)
(defconstant +max-media-cnt+ 2)

(defparameter *complete* (convert-to-foreign 0 'pj-bool))
(defparameter *endpt* (null-pointer))
(defvar *cp* (foreign-alloc 'pj-caching-pool))
(defparameter *med-endpt* (null-pointer))
(defvar *med-tpinfo* (make-array +max-media-cnt+ :initial-contents (loop repeat +max-media-cnt+
									    collecting (foreign-alloc 'pjmedia-transport-info))))
(defvar *med-transport* (make-array +max-media-cnt+ :initial-element (null-pointer)))
(defvar *sock-info* (foreign-alloc 'pjmedia-sock-info :count +max-media-cnt+))
;;;Call variables
(defvar *inv* (null-pointer))
(defvar *med-stream* (null-pointer))
;;(defvar *snd-port* (null-pointer))

(defvar *mod-simpleua* (foreign-alloc 'pjsip-module))

(defmacro assert-success (expr)
  `(assert (= ,expr 0)))

(defun pj-success (val)
  (= val 0))

(defun load-pjsip-libraries ()
  (pushnew #p"/usr/local/lib" *foreign-library-directories* :test #'equalp)
  (use-foreign-library libpj)
  (use-foreign-library libpjsip)
  (use-foreign-library libpjsip-ua)
  (use-foreign-library libpjsua)
  (use-foreign-library libpjmedia)
  (use-foreign-library libpjmedia-codec)
  (use-foreign-library libpjlib-util))

(defcallback on-rx-request pj-bool ((rdata (:pointer pjsip-rx-data)))
  (unwind-protect
       (with-foreign-objects ((hostaddr 'pj-sockaddr)
			      (local-uri 'pj-str)
			      (dlg '(:pointer pjsip-dialog))
			      (local-sdp '(:pointer pjmedia-sdp-session))
			      (tdata '(:pointer pjsip-tx-data)))
	 (let ((id-val (foreign-slot-value
			(foreign-slot-pointer
			 (foreign-slot-pointer
			  (foreign-slot-value 
			   (foreign-slot-pointer (foreign-slot-value rdata 'pjsip-rx-data 'msg-info) 'rx-data-msg-info 'msg)
			   'pjsip-msg 'line)
			  'msg-line 'req)
			 'pjsip-request-line 'method)
			'pjsip-method 'id)))
	   (if (not (eql :pjsip-invite-method (foreign-enum-keyword 'pjsip-method-e id-val)))
	       (if (not (eql :pjsip-ack-method (foreign-enum-keyword 'pjsip-method-e id-val)))
		   (with-foreign-object (pjs 'pj-str)
		     (pjsip-endpt-respond-stateless *endpt* rdata 500 (lisp-to-pj-str "Unable to handle request" pjs)
						    (null-pointer) (null-pointer)))
		   1)
	       ))))
  1)

(defun init ()
  (load-pjsip-libraries)
  (foreign-funcall "bzero" :pointer *mod-simpleua* :int (foreign-type-size 'pjsip-module) :void)
  (with-foreign-slots ((name priority on-rx-request) *mod-simpleua* pjsip-module)
    (lisp-string-to-pj-str "mod-simpleua" name)
    (setf priority (foreign-enum-value 'pjsip-module-priority :pjsip-mod-priority-application)
	  id -1
	  on-rx-request (callback on-rx-request))))

(defcallback call-on-state-changed :void ((inv (:pointer pjsip-inv-session)) (e (:pointer pjsip-event)))
  (declare (ignorable e))
  (if (eql (foreign-enum-keyword 'pjsip-inv-state (inv-session-state inv)) :pjsip-inv-state-disconnected)
      (format t "Call DISCONNECTED [reason = ~A]" (foreign-enum-keyword 'pjsip-status-code (inv-session-cause inv)))
      (format t "Call state changed to ~A" (foreign-enum-keyword 'pjsip-inv-state (inv-session-state inv)))))

(defcallback call-on-forked :void ((inv (:pointer pjsip-inv-session)) (e (:pointer pjsip-event)))
  (declare (ignore inv e)))

(defcallback call-on-media-update :void ((inv (:pointer pjsip-inv-session)) (status pj-status))
  )

(defun run-agent (&optional uri)
  (with-foreign-object (pool-ptr '(:pointer pj-pool))
    (let (status)
      (assert-success (pj-init))
      (pj-log-set-level 5)
      (assert-success (pjlib-util-init))
      (pj-caching-pool-init *cp* (pj-pool-factory-get-default-policy) 0)
      (let ((endpt-name (machine-instance)))
	(assert-success (pjsip-endpt-create (foreign-slot-pointer *cp* 'pj-caching-pool 'factory) endpt-name *endpt*)))
      (with-foreign-object (addr 'pj-sockaddr)
	(pjsip-sockaddr-init *pj-af-inet* addr (null-pointer) +sip-port+) ;;ipv4
	(assert-success (pjsip-udp-transport-start *endpt* (foreign-slot-pointer addr 'pj-sockaddr 'ipv4)
						   (null-pointer) 1 (null-pointer))))
      ;;init transaction layer
      (assert-success (pjsip-tsx-layer-init-module *endpt*))
      ;;init UA layer
      (assert-success (pjsip-ua-init-module *endpt* (null-pointer)))

      ;; init INVITE session module
      (with-foreign-object (inv-cb 'pjsip-inv-callback)
	(pj-bzero inv-cb (foreign-type-size 'pjsip-inv-callback))
	(with-foreign-slots ((on-state-changed on-new-session on-media-update) inv-cb pjsip-inv-callback)
	  (setf on-state-changed (callback call-on-state-changed)
		on-new-session (callback call-on-forked)
		on-media-update (callback call-on-media-update))
	  (assert-success (pjsip-inv-usage-init *endpt* inv-cb))))
      (assert-success (pjsip-100rel-init-module *endpt*))
      (assert-success (pjsip-endpt-register-module *endpt* *mod-simpleua*))

      ;;init media endpoint
      (assert-success (pjmedia-endpt-create (foreign-slot-pointer *cp* 'pj-caching-pool 'factory) (null-pointer) 1 *med-endpt*))

      ;;init G711
      (assert-success (pjmedia-codec-g711-init *med-endpt*))
      (loop for i from 0 below (length *med-transport*) do
	   (assert-success (pjmedia-transport-udp-create3 *med-endpt* *pj-af-inet* (null-pointer) (null-pointer) (+ (* i 2) +rtp-port+)
							  0 (aref *med-transport* i)))

	   (pjmedia-transport-info-init (aref *med-tpinfo* i))
	   (pjmedia-transport-get-info (aref *med-transport* i) (aref *med-tpinfo* i))

	   (foreign-funcall "memcpy" :pointer (mem-aref *sock-info* i)
			    :pointer (foreign-slot-pointer (aref *med-tpinfo* i) 'pjmedia-transport-info 'sock-info)
			    :int (foreign-type-size 'pjmedia-sock-info)
			    :void))
      (if uri
	  (with-foreign-objects ((hostaddr 'pj-sockaddr)
				 (dst-uri 'pj-str)
				 (local-uri 'pj-str)
				 (dlg '(:pointer pjsip-dialog))
				 (local-sdp '(:pointer pjmedia-sdp-session))
				 (tdata '(:pointer pjsip-tx-data)))
	    (unless (pj-success (pj-gethostip *pj-af-inet* hostaddr))
	      (format t "Unable to retrieve local host IP")
	      (return-from run-agent nil))
	    (lisp-string-to-pj-str (format nil "<sip:simpleuac@~A:~D>" (pj-str-to-lisp hostaddr) +sip-port+) local-uri)
	    ;;create UAC dialog
	    (assert-success (pjsip-dlg-create-uac (pjsip-ua-instance) local-uri local-uri dst-uri dst-uri dlg))
	    (assert-success (pjmedia-endpt-create-sdp *med-endpt* (foreign-slot-pointer (mem-ref dlg 'pjsip-dialog) 'pjsip-dialog 'pool)
						      +max-media-cnt+ *sock-info* local-sdp))

	    ;;create the INVITE session and pass the above created SDP
	    (assert-success (pjsip-inv-create-uac dlg local-sdp 0 *inv*))

	    (assert-success (pjsip-inv-invite *inv* tdata))
	    ;;get the ball rolling over the net
	    (assert-success (pjsip-inv-send-msg *inv* tdata)))
	  (format t "Ready to accept incoming calls.."))
      
      (loop until *complete* do
	   (with-foreign-object (timeout 'pj-time-val)
	     (setf (foreign-slot-value timeout 'pj-time-val 'sec) 0
		   (foreign-slot-value timeout 'pj-time-val 'msec) 10)
	     (pjsip-endpt-handle-events *endpt* timeout)))

      (unless (null-pointer-p *med-stream*)
	(pjmedia-stream-destroy *med-stream*))

      ;;destroy media transports, deinit endpoints..
      (loop for i from 0 below +max-media-cnt+ do
	   (unless (null-pointer-p (aref *med-transport* i))
	     (pjmedia-transport-close (aref *med-transport* i))))

      (unless (null-pointer-p *med-endpt*)
	(pjmedia-endpt-destroy *med-endpt*))

      (unless (null-pointer-p *endpt*)
	(pjsip-endpt-destroy *endpt*))

      ;;release pool
      (unless (null-pointer-p pool-ptr)
	(pj-pool-release pool-ptr))))
  t)

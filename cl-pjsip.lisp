;;;; Library wrapper

(in-package #:cl-pjsip)

(define-foreign-library libpjlib-util
  (:unix (:or "libpjlib-util.so")))

(define-foreign-library libpj
  (:unix (:or "libpj.so.2" "libpj.so")))

(define-foreign-library libpjsip
  (:unix (:or "libpjsip.so.2" "libpjsip.so")))

(define-foreign-library libpjsip-ua
  (:unix (:or "libpjsip-ua.so")))

(define-foreign-library libpjsua
  (:unix (:or "libpjsua.so")))

(define-foreign-library libpjmedia
  (:unix (:or "libpjmedia.so")))

(define-foreign-library libpjmedia-codec
  (:unix (:or "libpjmedia-codec.so")))

(define-foreign-library libpjmedia-audiodev
  (:unix (:or "libpjmedia-audiodev.so")))

(defconstant +pj-invalid-socket+ -1)

(defconstant +pj-success+ 0)
(defconstant +pj-true+ 1)
(defconstant +pj-false+ 0)

(defconstant +pj-errno-start-status+ 70000)
(defconstant +pj-enotsup+ (+ +pj-errno-start-status+ 12))

(eval-when (:compile-toplevel)
  (defconstant +pj-max-obj-name+ 32)
  (defconstant +pj-caching-pool-array-size+ 16)
  (defconstant +pool-buf-size+ 512)	;256 * sizeof(size_t) / 4
  (defconstant +pjmedia-codec-mgr-max-codecs+ 32)
  (defconstant +pjsip-max-module+ 32)
  (defconstant +max-threads+ 16)
  (defconstant +pjsip-max-pkt-len+ 4000)
  (defconstant +pj-inet6-addrstrlen+ 46)
  (defconstant +pjsip-generic-array-max-count+ 32)
  (defconstant +pjmedia-format-detail-user-size+ 1)
  (defconstant +pjsip-max-resolved-addresses+ 8)
  (defconstant +pj-max-sockopt-params+ 4))

(defmacro assert-success (expr)
  `(assert (= ,expr +pj-success+)))

(defun pj-success (val)
  (= val +pj-success+))

(defctype size :unsigned-long)
(defctype pj-status :int)

(defctype pj-size size)

(defctype pj-ssize :long)

(defctype pj-bool :boolean)

(defctype pj-int32 :int)

(defctype pj-uint32 :uint)

(defctype pj-int16 :short)

(defctype pj-uint16 :ushort)

(defctype pj-uint64 :uint64)

(defctype pj-int64 :int64)

(defcstruct pj-str
  (ptr (:pointer :char))
  (slen :long))

(defctype pj-str (:struct pj-str))

;;;should really really fix this crap, once get the basics working
(defun lisp-string-to-pj-str (string pjstring)
  "Map Lisp strings to pj_str"
  (check-type string string)
  (pj-strcpy2 pjstring string)
  #+nil(with-foreign-slots ((ptr slen) pjstring pj-str)
    (setf slen (length string))
    (setf ptr (foreign-alloc :char :count slen))
    (loop for i from 0 below slen do
	 (setf (mem-aref ptr :char i) (char-code (char string i))))
    pjstring))

(defun pj-str-length (pjstr)
  (foreign-slot-value pjstr 'pj-str 'slen))

(defun pj-str-to-lisp (pointer &key (encoding *default-foreign-encoding*))
  (unless (null-pointer-p pointer)
    (let ((count (pj-str-length pointer))
	  ;; it is not clear yet if PJSIP strings orthogonal to encoding capacity
	  (mapping (cffi::lookup-mapping cffi::*foreign-string-mappings* encoding)))
      (multiple-value-bind (size new-end)
          (funcall (cffi::code-point-counter mapping)
                   pointer 0 count (1- array-total-size-limit))
	(let ((string (make-string size)))
	  (funcall (cffi::decoder mapping)
		   (foreign-slot-value pointer 'pj-str 'ptr) 0 new-end string 0)
	  string)))))

(defcenum pjsip-module-priority
  (:pjsip-mod-priority-transport-layer 8)
  (:pjsip-mod-priority-tsx-layer 16)
  (:pjsip-mod-priority-ua-proxy-layer 32)
  (:pjsip-mod-priority-dialog-usage 48)
  (:pjsip-mod-priority-application 64))

(defcstruct pj-pool-factory-policy
  ;;pjsip's own callbackery, we're not going to disturb this
  (block-alloc :pointer)
  (block-free :pointer)
  (callback :pointer)
  (flags :uint))

(defctype pj-pool-factory-policy (:struct pj-pool-factory-policy))

(defcstruct pj-pool-factory
  (policy (:struct pj-pool-factory-policy))
  ;;pjsip's own callbackery, we're not going to disturb this
  (create-pool :pointer)
  (release-pool :pointer)
  (dump-status :pointer)
  (on-block-alloc :pointer)
  (on-block-free :pointer))

(defctype pj-pool-factory (:struct pj-pool-factory))

#|
(defcstruct pj-pool-mem
  (next :pointer))

(defctype pj-pool-mem (:struct pj-pool-mem))

;; pool_alt.h definitionx
(defcstruct pj-pool
  (first-mem (:pointer (:struct pj-pool-mem)))
  (factory (:pointer (:struct pj-pool-factory)))
  (obj-name :char :count 32)
  (cb :pointer)) ;callback
|#

(defcstruct pj-list
  (prev (:pointer :void))
  (next (:pointer :void)))

(defctype pj-list (:struct pj-list))

(defcstruct pj-pool-block
  (list pj-list)
  (buf (:pointer :uchar))
  (cur (:pointer :uchar))
  (end (:pointer :uchar)))

(defctype pj-pool-block (:struct pj-pool-block))

(defcstruct pj-pool
  (list pj-list)
  (obj-name :char :count #.+pj-max-obj-name+)
  (factory (:pointer pj-pool-factory))
  (factory-data (:pointer :void))
  (capacity pj-size)
  (increment-size pj-size)
  (block-list pj-pool-block)
  (callback :pointer))

(defctype pj-pool (:struct pj-pool))

(defcstruct pj-caching-pool
  (factory (:struct pj-pool-factory))
  (capacity pj-size)
  (max-capacity pj-size)
  (used-count pj-size)
  (used-size pj-size)
  (peak-used-size pj-size)
  (free-list (:struct pj-list) :count #.+pj-caching-pool-array-size+)
  (used-list (:struct pj-list))
  (pool-buf :char :count #.+pool-buf-size+) 
  (lock :pointer))

(defctype pj-caching-pool (:struct pj-caching-pool))

(defcenum pjsip-hdr-e
  :pjsip_h_accept
  :pjsip_h_accept_encoding_unimp	
  :pjsip_h_accept_language_unimp	
  :pjsip_h_alert_info_unimp		
  :pjsip_h_allow
  :pjsip_h_authentication_info_unimp	
  :pjsip_h_authorization
  :pjsip_h_call_id
  :pjsip_h_call_info_unimp		
  :pjsip_h_contact
  :pjsip_h_content_disposition_unimp	
  :pjsip_h_content_encoding_unimp	
  :pjsip_h_content_language_unimp	
  :pjsip_h_content_length
  :pjsip_h_content_type
  :pjsip_h_cseq
  :pjsip_h_date_unimp			
  :pjsip_h_error_info_unimp		
  :pjsip_h_expires
  :pjsip_h_from
  :pjsip_h_in_reply_to_unimp		
  :pjsip_h_max_forwards
  :pjsip_h_mime_version_unimp		
  :pjsip_h_min_expires
  :pjsip_h_organization_unimp		
  :pjsip_h_priority_unimp		
  :pjsip_h_proxy_authenticate
  :pjsip_h_proxy_authorization
  :pjsip_h_proxy_require_unimp	
  :pjsip_h_record_route
  :pjsip_h_reply_to_unimp		
  :pjsip_h_require
  :pjsip_h_retry_after
  :pjsip_h_route
  :pjsip_h_server_unimp		
  :pjsip_h_subject_unimp		
  :pjsip_h_supported
  :pjsip_h_timestamp_unimp		
  :pjsip_h_to
  :pjsip_h_unsupported
  :pjsip_h_user_agent_unimp		
  :pjsip_h_via
  :pjsip_h_warning_unimp		
  :pjsip_h_www_authenticate
  :pjsip_h_other)

(defcstruct pjsip-hdr
  (list pj-list)
  (type pjsip-hdr-e)
  (name pj-str)
  (sname pj-str)
  (vptr :pointer))

(defctype pjsip-hdr (:struct pjsip-hdr))

(defcunion pj-in6-addr
  (s6-addr :uint8 :count 16)
  (u6-addr32 pj-uint32 :count 4))

;;;on Darwin
#+darwin(defcstruct pj-sockaddr-in6
  (sin6-zero-len :uint8)
  (sin6-family :uint8)
  ;;assume zero len
  ;;(sin6-family :uint16)
  (sin6-port pj-uint16)
  (sin6-flowinfo pj-uint32)
  (sin6-addr (:union pj-in6-addr))
  (sin6-scope-id pj-uint32))

;;; Linux
#+linux(defcstruct pj-sockaddr-in6
  (sin6-family pj-uint16)
  (sin6-port pj-uint16)
  (sin6-flowinfo pj-uint32)
  (sin6-addr (:union pj-in6-addr))
  (sin6-scope-id pj-uint32))

(defctype pj-sockaddr-in6 (:struct pj-sockaddr-in6))

(defcstruct pj-in-addr
  (s-addr pj-uint32))

(defctype pj-in-addr (:struct pj-in-addr))

;;;on Darwin
#+darwin(defcstruct pj-sockaddr-in
  (sin-zero-len :uint8)
  (sin-family :uint8)
  ;;assume zero len
  ;;(sin-family :uint16)
  (sin-port pj-uint16)
  (sin-addr (:struct pj-in-addr))
  (sin-zero :char :count 8))

;;; Linux
#+linux(defcstruct pj-sockaddr-in
  (sin-family pj-uint16)
  (sin-port pj-uint16)
  (sin-addr (:struct pj-in-addr))
  (sin-zero :char :count 8))

(defctype pj-sockaddr-in (:struct pj-sockaddr-in))

;;; Darwin
#+nil(defcstruct pj-addr-hdr
  (sa-zero-len :uint8)
  (sa-family :uint8))

(defcstruct pj-addr-hdr
  (sa-family pj-uint16))

(defctype pj-addr-hdr (:struct pj-addr-hdr))

(defcunion pj-sockaddr
  (addr (:struct pj-addr-hdr))
  (ipv4 (:struct pj-sockaddr-in))
  (ipv6 (:struct pj-sockaddr-in6)))

(defctype pj-sockaddr (:union pj-sockaddr))

(defcstruct pjsip-host-port
  (host pj-str)
  (port :int))

(defctype pjsip-host-port (:struct pjsip-host-port))

(defcstruct pjsip-transport-key
  (type :long)
  (rem-addr pj-sockaddr))

(defctype pjsip-transport-key (:struct pjsip-transport-key))

(defcenum pjsip-transport-dir
  :pjsip-tp-dir-none
  :pjsip-tp-dir-outcoming
  :pjsip-tp-dir-incoming)

(defctype pj-timer-id :int)

(defcstruct pj-time-val
  (sec :long)
  (msec :long))

(defctype pj-time-val (:struct pj-time-val))

(defcstruct pj-timer-entry
  (user-data (:pointer :void))
  (id :int)
  (cb :pointer) ;callbackery
  (_timer-id pj-timer-id)
  (_timer-value pj-time-val)
  (_grp-lock :pointer)) ;dangling

(defctype pj-timer-entry (:struct pj-timer-entry))

(defcunion pj-timestamp
  (w pj-uint64) ;lo + hi 32 bit components
  (u64 pj-uint64))

(defctype pj-timestamp (:union pj-timestamp))

(defcstruct pjsip-ua-init-param
  ;; yet another callback stub
  (on-dlg-forked :pointer))

(defctype pjsip-ua-init-param (:struct pjsip-ua-init-param))

(defcstruct pjsip-module
  (list pj-list)
  (name pj-str)
  (id :int)
  (priority :int)
  ;;callbackery.. dangling
  (load :pointer)
  (start :pointer)
  (stop :pointer)
  (unload :pointer)
  (on-rx-request :pointer)
  (on-rx-response :pointer)
  (on-tx-request :pointer)
  (on-tx-response :pointer)
  (on-tsx-state :pointer))

(defctype pjsip-module (:struct pjsip-module))

(defcstruct pjsip-inv-callback ;all callbacks are dangling defs..
  (on-state-changed :pointer)
  (on-new-session :pointer)
  (on-tsx-state-changed :pointer)
  (on-rx-offer :pointer)
  (on-rx-reinvite :pointer)
  (on-create-offer :pointer)
  (on-media-update :pointer)
  (on-send-ack :pointer)
  (on-redirected :pointer))

(defctype pjsip-inv-callback (:struct pjsip-inv-callback))

(defcstruct pjmedia-codec-factory
  ;;pj-list really via c macrology originally
  (prev (:pointer :void))
  (next (:pointer :void))
  (factory-data (:pointer :void))
  (op :pointer)) ;dangling

(defctype pjmedia-codec-factory (:struct pjmedia-codec-factory))

(defcenum pjmedia-codec-priority
  (:pjmedia-codec-prio-highest 255)
  (:pjmedia-codec-prio-next-higher 254)
  (:pjmedia-codec-prio-normal 128)
  (:pjmedia-codec-prio-lowest 1)
  (:pjmedia-codec-prio-disabled 0))

(defcenum pjmedia-type
    :pjmedia-type-none
    :pjmedia-type-audio
    :pjmedia-type-video
    :pjmedia-type-application
    :pjmedia-type-unknown)

(defcstruct pjmedia-codec-info
  (type pjmedia-type)
  (pt :uint)
  (encoding-name pj-str)
  (clock-rate :uint)
  (channel-cnt :uint))

(defctype pjmedia-codec-info (:struct pjmedia-codec-info))

(defcstruct pjmedia-codec-desc
  (info (:struct pjmedia-codec-info))
  (id :char :count #.+pj-max-obj-name+)
  (prio pjmedia-codec-priority)
  (factory (:pointer (:struct pjmedia-codec-factory)))
  (param :pointer)) ;dangling

(defctype pjmedia-codec-desc (:struct pjmedia-codec-desc))
					
(defcstruct pjmedia-codec-mgr
  (pf (:pointer (:struct pj-pool-factory)))
  (pool (:pointer (:struct pj-pool)))
  (mutex :pointer) ;dangling
  (factory-list (:struct pjmedia-codec-factory))
  (codec-cnt :uint)
  (codec-desc (:struct pjmedia-codec-desc) :count #.+pjmedia-codec-mgr-max-codecs+))

(defctype pjmedia-codec-mgr (:struct pjmedia-codec-mgr))

(defcstruct exit-cb
  (list (:struct pj-list))
  (func :pointer)) ;dangling

(defctype exit-cb (:struct exit-cb))

(defcstruct pjsip-endpoint
  (pool (:pointer (:struct pj-pool)))
  (mutex :pointer) ;dangling
  (pf (:pointer (:struct pj-pool-factory)))
  (name pj-str)
  (timer-heap :pointer) ;dangling
  (transport-mgr :pointer) ;dangling
  (ioqueue :pointer) ;dangling
  (ioq-last-err pj-status)
  (resolver :pointer) ;dangling
  (mod-mutex :pointer) ;dangling
  (modules (:pointer (:struct pjsip-module)) :count #.+pjsip-max-module+)
  (module-list (:struct pjsip-module))
  (cap-hdr (:struct pjsip-hdr))
  (req-hdr (:struct pjsip-hdr))
  (exit-cb-list (:struct exit-cb)))

(defctype pjsip-endpoint (:struct pjsip-endpoint))

(defcstruct pjsip-transport
  (obj-name :char :count #.+pj-max-obj-name+)
  (pool (:pointer pj-pool))
  (ref-cnt :pointer) ;dangling
  (lock :pointer) ;dangling
  (tracing pj-bool)
  (is-shutdown pj-bool)
  (is-destroying pj-bool)

  (key pjsip-transport-key)

  (type-name (:pointer :char))
  (flag :uint)
  (info (:pointer :char))

  (addr-len :int)
  (local-addr pj-sockaddr)
  (local-name pjsip-host-port)
  (remote-name pjsip-host-port)
  (dir pjsip-transport-dir)

  (endpt (:pointer pjsip-endpoint))
  (tpmgr :pointer) ;dangling
  (factory :pointer) ;dangling

  (idle-timer pj-timer-entry)
  (last-recv-ts pj-timestamp)
  (last-recv-len pj-size)

  (data (:pointer :void))

  (send-msg :pointer)
  (do-shutdown :pointer)
  (destroy :pointer))

(defctype pjsip-transport (:struct pjsip-transport))

(defcstruct pjmedia-endpt
  (pool (:pointer (:struct pj-pool)))
  (pf (:pointer (:struct pj-pool-factory)))
  (codec-mgr (:struct pjmedia-codec-mgr))
  (ioqueue :pointer) ;dangling
  (own-ioqueue pj-bool)
  (thread-cnt :uint)
  (thread :pointer :count #.+max-threads+)
  (quit-flag pj-bool)
  (has-telephone-event pj-bool)
  (exit-cb-list (:struct exit-cb)))

(defctype pjmedia-endpt (:struct pjmedia-endpt))

(defcenum pjmedia-transport-type
  :pjmedia-transport-type-udp
  :pjmedia-transport-type-ice
  :pjmedia-transport-type-srtp
  :pjmedia-transport-type-user)

(defcstruct pjmedia-transport-op
  ;;callbackery
  (get-info :pointer)
  (attach :pointer)
  (detach :pointer)
  (send-rtp :pointer)
  (send-rtcp :pointer)
  (send-rtcp2 :pointer)
  (media-create :pointer)
  (encode-sdp :pointer)
  (media-start :pointer)
  (media-stop :pointer)
  (simulate-lost :pointer)
  (destroy :pointer))

(defctype pjmedia-transport-op (:struct pjmedia-transport-op))

(defcstruct pjmedia-transport
  (name :char :count #.+pj-max-obj-name+)
  (type pjmedia-transport-type)
  (op (:pointer (:struct pjmedia-transport-op)))
  (user-data (:pointer :void)))

(defctype pjmedia-transport (:struct pjmedia-transport))

(defctype pj-sock :long)

(defcstruct pjmedia-sock-info
  (rtp-sock pj-sock)
  (rtp-addr-name (:union pj-sockaddr))
  (rtcp-sock pj-sock)
  (rtcp-addr-name (:union pj-sockaddr)))

(defctype pjmedia-sock-info (:struct pjmedia-sock-info))

(defcstruct pjmedia-transport-specific-info
  (type pjmedia-transport-type)
  (cbsize :int)
  (buffer :long :count 36)) ;36 * sizeof(long)

(defctype pjmedia-transport-specific-info (:struct pjmedia-transport-specific-info))

(defcstruct pjmedia-transport-info
  (sock-info (:struct pjmedia-sock-info))
  (src-rtp-name (:union pj-sockaddr))
  (src-rtcp-name (:union pj-sockaddr))
  (specific-info-cnt :uint)
  (spc-info (:struct pjmedia-transport-specific-info) :count 4))

(defctype pjmedia-transport-info (:struct pjmedia-transport-info))

(defctype pjsip-user-agent (:struct pjsip-module))

(defcenum pjsip-dialog-state
  :pjsip-dialog-state-null
  :pjsip-dialog-state-established)

(defcenum pjsip-uri-context-e
  :pjsip-uri-in-req-uri
  :pjsip-uri-fromto-hdr
  :pjsip-uri-in-contact-hdr
  :pjsip-uri-in-routing-hdr
  :pjsip-uri-other)

(defcstruct pjsip-uri-vptr
  (p-get-scheme :pointer)
  (p-get-uri :pointer)
  (p-print :pointer)
  (p-compare :pointer)
  (p-clone :pointer))

(defctype pjsip-uri-vptr (:struct pjsip-uri-vptr))

(defcstruct pjsip-uri
  (vptr (:pointer pjsip-uri-vptr)))

(defctype pjsip-uri (:struct pjsip-uri))

(defcenum pjsip-status-code
  (:pjsip_sc_trying 100)
  (:pjsip_sc_ringing 180)
  (:pjsip_sc_call_being_forwarded 181)
  (:pjsip_sc_queued 182)
  (:pjsip_sc_progress 183)
  (:pjsip_sc_ok 200)
  (:pjsip_sc_accepted 202)
  (:pjsip_sc_multiple_choices 300)
  (:pjsip_sc_moved_permanently 301)
  (:pjsip_sc_moved_temporarily 302)
  (:pjsip_sc_use_proxy 305)
  (:pjsip_sc_alternative_service 380)
  (:pjsip_sc_bad_request 400)
  (:pjsip_sc_unauthorized 401)
  (:pjsip_sc_payment_required 402)
  (:pjsip_sc_forbidden 403)
  (:pjsip_sc_not_found 404)
  (:pjsip_sc_method_not_allowed 405)
  (:pjsip_sc_not_acceptable 406)
  (:pjsip_sc_proxy_authentication_required 407)
  (:pjsip_sc_request_timeout 408)
  (:pjsip_sc_gone 410)
  (:pjsip_sc_request_entity_too_large 413)
  (:pjsip_sc_request_uri_too_long 414)
  (:pjsip_sc_unsupported_media_type 415)
  (:pjsip_sc_unsupported_uri_scheme 416)
  (:pjsip_sc_bad_extension 420)
  (:pjsip_sc_extension_required 421)
  (:pjsip_sc_session_timer_too_small 422)
  (:pjsip_sc_interval_too_brief 423)
  (:pjsip_sc_temporarily_unavailable 480)
  (:pjsip_sc_call_tsx_does_not_exist 481)
  (:pjsip_sc_loop_detected 482)
  (:pjsip_sc_too_many_hops 483)
  (:pjsip_sc_address_incomplete 484)
  (:pjsip_ac_ambiguous 485)
  (:pjsip_sc_busy_here 486)
  (:pjsip_sc_request_terminated 487)
  (:pjsip_sc_not_acceptable_here 488)
  (:pjsip_sc_bad_event 489)
  (:pjsip_sc_request_updated 490)
  (:pjsip_sc_request_pending 491)
  (:pjsip_sc_undecipherable 493)
  (:pjsip_sc_internal_server_error 500)
  (:pjsip_sc_not_implemented 501)
  (:pjsip_sc_bad_gateway 502)
  (:pjsip_sc_service_unavailable 503)
  (:pjsip_sc_server_timeout 504)
  (:pjsip_sc_version_not_supported 505)
  (:pjsip_sc_message_too_large 513)
  (:pjsip_sc_precondition_failure 580)
  (:pjsip_sc_busy_everywhere 600)
  (:pjsip_sc_decline 603)
  (:pjsip_sc_does_not_exist_anywhere 604)
  (:pjsip_sc_not_acceptable_anywhere 606)
  (:pjsip_sc_tsx_timeout 408)		;pjsip_sc_request_timeout
  (:pjsip_sc_tsx_transport_error 503)	;pjsip_sc_service_unavailable
  (:pjsip_sc__force_32bit #x7fffffff))

(defcstruct pjsip-target
  ;;pj-list really via c macrology originally
  (prev (:pointer :void))
  (next (:pointer :void))
  (uri (:pointer (:struct pjsip-uri)))
  (q1000 :int)
  (code pjsip-status-code)
  (reason pj-str))

(defctype pjsip-target (:struct pjsip-target))

(defcstruct pjsip-target-set
  (head (:struct pjsip-target))
  (current (:pointer (:struct pjsip-target))))

(defctype pjsip-target-set (:struct pjsip-target-set))

(defcstruct pjsip-param
  ;;pj-list really via c macrology originally
  (prev (:pointer :void))
  (next (:pointer :void))
  (name pj-str)
  (value pj-str))

(defctype pjsip-param (:struct pjsip-param))

(defcstruct pjsip-fromto-hdr
  (hdr pjsip-hdr)
  (uri (:pointer (:struct pjsip-uri)))
  (tag pj-str)
  (other-param (:struct pjsip-param)))

(defctype pjsip-fromto-hdr (:struct pjsip-fromto-hdr))
(defctype pjsip-from-hdr (:struct pjsip-fromto-hdr))
(defctype pjsip-to-hdr (:struct pjsip-fromto-hdr))

(defcstruct pjsip-contact-hdr
  (hdr pjsip-hdr)
  (star :int)
  (uri (:pointer (:struct pjsip-uri)))
  (q1000 :int)
  (expires pj-int32)
  (other-param (:struct pjsip-param)))

(defctype pjsip-contact-hdr (:struct pjsip-contact-hdr))

(defcstruct pjsip-dlg-party
  (info (:pointer (:struct pjsip-fromto-hdr)))
  (info-str pj-str)
  (tag-hval pj-uint32)
  (contact (:pointer (:struct pjsip-contact-hdr)))
  (first-cseq pj-int32)
  (cseq pj-int32))

(defctype pjsip-dlg-party (:struct pjsip-dlg-party))

(defcstruct pjsip-cid-hdr
  (hdr pjsip-hdr)
  (id pj-str))

(defctype pjsip-cid-hdr (:struct pjsip-cid-hdr))

(defcstruct pjsip-name-addr
  (vptr :pointer) ;dangling
  (display pj-str)
  (uri (:pointer (:struct pjsip-uri))))

(defctype pjsip-name-addr (:struct pjsip-name-addr))

(defcstruct pjsip-routing-hdr
  (hdr (:struct pjsip-hdr))
  (name-addr (:struct pjsip-name-addr))
  (other-param (:struct pjsip-param)))

(defctype pjsip-routing-hdr (:struct pjsip-routing-hdr))

(defctype pjsip-route-hdr (:struct pjsip-routing-hdr))
(defctype pjsip-rr-hdr (:struct pjsip-routing-hdr))

(defcstruct pjsip-common-challenge
  (realm pj-str)
  (other-param (:struct pjsip-param)))

(defctype pjsip-common-challenge (:struct pjsip-common-challenge))

(defcstruct pjsip-digest-challenge
  (realm pj-str)
  (other-param (:struct pjsip-param))
  (domain pj-str)
  (nonce pj-str)
  (opaque pj-str)
  (stale :int)
  (algorithm pj-str)
  (qop pj-str))

(defctype pjsip-digest-challenge (:struct pjsip-digest-challenge))

(defcstruct pjsip-pgp-challenge
  (realm pj-str)
  (other-param (:struct pjsip-param))
  (version pj-str)
  (micalgorithm pj-str)
  (pubalgorithm pj-str)
  (nonce pj-str))

(defctype pjsip-pgp-challenge (:struct pjsip-pgp-challenge))

(defcunion u-challenge
  (common (:struct pjsip-common-challenge))
  (digest (:struct pjsip-digest-challenge))
  (pgp (:struct pjsip-pgp-challenge)))

(defcstruct pjsip-www-authenticate-hdr
  (decl-stub pjsip-hdr)
  (scheme pj-str)
  (challenge (:union u-challenge)))

(defctype pjsip-www-authenticate-hdr (:struct pjsip-www-authenticate-hdr))

(defcstruct pjsip-auth-clt-pref
  (initial-auth pj-bool)
  (algorithm pj-str))

(defctype pjsip-auth-clt-pref (:struct pjsip-auth-clt-pref))

(defcenum pjsip-auth-qop-type
  :pjsip-auth-qop-none
  :pjsip-auth-qop-auth
  :pjsip-auth-qop-auth-int
  :pjsip-auth-qop-unknown)

(defcstruct pjsip-cached-auth
  (list pj-list)
  (pool (:pointer (:struct pj-pool)))
  (realm pj-str)
  (is-proxy pj-bool)
  (qop-value pjsip-auth-qop-type)
  (stale-cnt :uint)
  (nc pj-uint32) ;PJSIP_AUTH_QOP_SUPPORT = 1
  (cnonce pj-str) ;PJSIP_AUTH_QOP_SUPPORT = 1
  (last-chal (:pointer (:struct pjsip-www-authenticate-hdr)))
  #+nil(cached-hdr (:struct pjsip-cached-auth-hdr)) ;no caching support, as it defaults to none in pjsip, but be careful
  )

(defctype pjsip-cached-auth (:struct pjsip-cached-auth))

(defcstruct pjsip-auth-clt-sess
  (pool (:pointer (:struct pj-pool)))
  (endpt (:pointer (:struct pjsip-endpoint)))
  (pref (:struct pjsip-auth-clt-pref))
  (cred-cnt :uint)
  (cred-info :pointer)
  (cached-auth (:struct pjsip-cached-auth)))

(defctype pjsip-auth-clt-sess (:struct pjsip-auth-clt-sess))

(defcenum pjsip-role-e
  (:pjsip-role-uac 0)
  :pjsip-role-uas
  ;;aliases to above
  (:pjsip-uac-role 0)
  :pjsip-uas-role)

(defcenum pjsip-tpselector-type
  :pjsip-tpselector-none
  :pjsip-tpselector-transport
  :pjsip-tpselector-listener)

(defcunion selector-u
  (transport (:pointer pjsip-transport))
  (listener :pointer)
  (ptr (:pointer :void)))

(defcstruct pjsip-tpselector
  (type pjsip-tpselector-type)
  (u (:union selector-u)))

(defctype pjsip-tpselector (:struct pjsip-tpselector))

(defcstruct pjsip-dialog
  ;;pj-list really via c macrology originally
  (prev (:pointer :void))
  (next (:pointer :void))
  (obj-name :char :count #.+pj-max-obj-name+)
  (pool (:pointer (:struct pj-pool)))
  (mutex :pointer) ;dangling
  (ua (:pointer pjsip-user-agent))
  (endpt (:pointer (:struct pjsip-endpoint)))
  (dlg-set (:pointer :void))
  (state pjsip-dialog-state)
  (target (:pointer (:struct pjsip-uri)))
  (target-set (:struct pjsip-target-set))
  (inv-hdr (:struct pjsip-hdr))
  (local (:struct pjsip-dlg-party))
  (remote (:struct pjsip-dlg-party))
  (rem-cap-hdr (:struct pjsip-hdr))
  (role pjsip-role-e)
  (uac-has-2xx pj-bool)
  (secure pj-bool)
  (add-allow pj-bool)
  (call-cid (:pointer pjsip-cid-hdr))
  (route-set pjsip-route-hdr)
  (route-set-frozen pj-bool)
  (auth-sess (:struct pjsip-auth-clt-sess))
  (sess-count :int)
  (tsx-count :int)
  (tpsel (:struct pjsip-tpselector))
  (usage-cnt :uint)
  (usage (:pointer (:struct pjsip-module)) :count #.+pjsip-max-module+)
  (mod-data (:pointer :void) :count #.+pjsip-max-module+)
  (via-addr (:struct pjsip-host-port))
  (via-tp (:pointer :void)))

(defctype pjsip-dialog (:struct pjsip-dialog))

(defcstruct pjmedia-sock-info
  (rtp-sock pj-sock)
  (rtp-addr-name (:union pj-sockaddr))
  (rtcp-sock pj-sock)
  (rtcp-addr-name (:union pj-sockaddr)))

(defctype pjmedia-sock-info (:struct pjmedia-sock-info))

(defcstruct sdp-session-origin
  (user pj-str)
  (id pj-uint32)
  (version pj-uint32)
  (net-type pj-str)
  (addr-type pj-str)
  (addr pj-str))

(defcstruct sdp-session-time
  (start pj-uint32)
  (stop pj-uint32))

(defcstruct pjmedia-sdp-session
  (origin (:struct sdp-session-origin))
  (name pj-str)
  (conn :pointer) ;dangling pjmedia_sdp_conn def
  (bandw-count :uint)
  (bandw :pointer :count 4) ;dangling def
  (time (:struct sdp-session-time))
  (attr-count :uint)
  (attr :pointer :count 68) ;dangling, 32*2 + 4
  (media-count :uint)
  (media :pointer :count 16)) ;dangling

(defctype pjmedia-sdp-session (:struct pjmedia-sdp-session))

(defcenum pjsip-inv-state
    :pjsip-inv-state-null	
    :pjsip-inv-state-calling	
    :pjsip-inv-state-incoming	
    :pjsip-inv-state-early	
    :pjsip-inv-state-connecting	
    :pjsip-inv-state-confirmed	
    :pjsip-inv-state-disconnected)

(defcstruct (pjsip-inv-session :conc-name inv-session-)
  (obj-name :char :count #.+pj-max-obj-name+)
  (pool (:pointer (:struct pj-pool)))
  (pool-prov (:pointer (:struct pj-pool)))
  (pool-active (:pointer (:struct pj-pool)))
  (state pjsip-inv-state)
  (cancelling pj-bool)
  (pending-cancel pj-bool)
  (pending-bye :pointer) ;dangling def
  (cause pjsip-status-code)
  (cause-next pj-str)
  (notify pj-bool)
  (cb-called :uint)
  (dlg (:pointer (:struct pjsip-dialog)))
  (role pjsip-role-e)
  (options :uint)
  (neg :pointer) ;dangling
  (sdp-neg-flags :uint)
  (invite-tsx :pointer) ;dangling
  (invite-req :pointer) ;dangling
  (last-answer :pointer) ;dangling
  (last-ack :pointer) ;dangling
  (last-ack-cseq pj-int32)
  (mod-data (:pointer :void) :count #.+pjsip-max-module+)
  (timer :pointer) ;dangling
  (following-fork pj-bool)
  (ref-cnt :pointer);dangling
  ) 

(defctype pjsip-inv-session (:struct pjsip-inv-session))

(defcstruct pj-ioqueue-op-key
  (internal (:pointer :void) :count 32)
  (activesock-data (:pointer :void))
  (user-data (:pointer :void)))

(defctype pj-ioqueue-op-key (:struct pj-ioqueue-op-key))

(defcstruct pjsip-rx-data-op-key
  (op-key (:struct pj-ioqueue-op-key))
  (rdata :pointer)) ;;fwd decl to -rx-data

(defctype pjsip-rx-data-op-key (:struct pjsip-rx-data-op-key))

(defcstruct rx-data-tp-info
  (pool (:pointer (:struct pj-pool)))
  (transport (:pointer (:struct pjsip-transport)))
  (tp-data (:pointer :void))
  (op-key (:struct pjsip-rx-data-op-key)))

(defctype rx-data-tp-info (:struct rx-data-tp-info))

(defcstruct rx-data-pkt-info
  (timestamp (:struct pj-time-val))
  (packet :char :count #.+pjsip-max-pkt-len+)
  (zero pj-uint32)
  (len size)
  (src-addr (:union pj-sockaddr))
  (src-addr-len :int)
  (src-name :char :count #.+pj-inet6-addrstrlen+)
  (src-port :int))

(defctype rx-data-pkt-info (:struct rx-data-pkt-info))

(defcstruct pjsip-media-type
  (type pj-str)
  (subtype pj-str)
  (param (:struct pjsip-param)))

(defctype pjsip-media-type (:struct pjsip-media-type))

(defcstruct pjsip-msg-body
  (content-type (:struct pjsip-media-type))
  (data (:pointer :void))
  (len :uint)
  (print-body :pointer) ;dangling callback
  (clone-data :pointer)) ;dangling callback

(defctype pjsip-msg-body (:struct pjsip-msg-body))

(defcenum pjsip-msg-type-e
  :pjsip-request-msg
  :pjsip-response-msg)

(defcenum pjsip-method-e
  :pjsip-invite-method   
  :pjsip-cancel-method 
  :pjsip-ack-method	 
  :pjsip-bye-method	 
  :pjsip-register-method
  :pjsip-options-method
  :pjsip-other-method)

(defcstruct pjsip-method
  (id pjsip-method-e)
  (name pj-str))

(defctype pjsip-method (:struct pjsip-method))

(defcstruct pjsip-request-line
  (method (:struct pjsip-method))
  (uri (:pointer (:struct pjsip-uri))))

(defctype pjsip-request-line (:struct pjsip-request-line))

(defcstruct pjsip-status-line
  (code :int)
  (reason pj-str))

(defctype pjsip-status-line (:struct pjsip-status-line))

(defcunion msg-line
  (req (:struct pjsip-request-line))
  (status (:struct pjsip-status-line)))

(defcstruct pjsip-msg
  (type pjsip-msg-type-e)
  (line (:union msg-line))
  (hdr (:struct pjsip-hdr))
  (body (:pointer (:struct pjsip-msg-body))))

(defctype pjsip-msg (:struct pjsip-msg))

(defcstruct pjsip-generic-int-hdr
  (hdr (:struct pjsip-hdr))
  (ivalue pj-int32))

(defctype pjsip-generic-int-hdr (:struct pjsip-generic-int-hdr))

(defctype pjsip-max-fwd-hdr (:struct pjsip-generic-int-hdr))

(defcstruct pjsip-via-hdr
  (hdr (:struct pjsip-hdr))
  (transport pj-str)
  (sent-by (:struct pjsip-host-port))
  (ttl-param :int)
  (rport-param :int)
  (maddr-param pj-str)
  (recvd-param pj-str)
  (branch-param pj-str)
  (other-param (:struct pjsip-param))
  (comment pj-str))

(defcstruct pjsip-cseq-hdr
  (hdr (:struct pjsip-hdr))
  (cseq pj-int32)
  (method (:struct pjsip-method)))

(defcstruct pjsip-ctype-hdr
  (hdr (:struct pjsip-hdr))
  (media (:struct pjsip-media-type)))

(defcstruct pjsip-clen-hdr
  (hdr (:struct pjsip-hdr))
  (len :int))

(defctype pjsip-ctype-hdr (:struct pjsip-ctype-hdr))
(defctype pjsip-clen-hdr (:struct pjsip-clen-hdr))
(defctype pjsip-via-hdr (:struct pjsip-via-hdr))
(defctype pjsip-cseq-hdr (:struct pjsip-cseq-hdr))

(defcstruct pjsip-generic-array-hdr
  (hdr (:struct pjsip-hdr))
  (count :uint)
  (values pj-str :count #.+pjsip-generic-array-max-count+))

(defctype pjsip-generic-array-hdr (:struct pjsip-generic-array-hdr))
(defctype pjsip-require-hdr (:struct pjsip-generic-array-hdr))
(defctype pjsip-supported-hdr (:struct pjsip-generic-array-hdr))

(defcstruct pjsip-parser-err-report
  (list (:struct pj-list))
  (except-code :int)
  (line :int)
  (col :int)
  (hname pj-str))

(defctype pjsip-parser-err-report (:struct pjsip-parser-err-report))

(defcstruct rx-data-msg-info
  (msg-buf (:pointer :char))
  (len :int)
  (msg (:pointer (:struct pjsip-msg)))
  (info (:pointer :char))
  (cid (:pointer pjsip-cid-hdr))
  (from (:pointer pjsip-from-hdr))
  (to (:pointer pjsip-to-hdr))
  (via (:pointer pjsip-via-hdr))
  (cseq (:pointer pjsip-cseq-hdr))
  (max-fwd (:pointer pjsip-max-fwd-hdr))
  (route (:pointer pjsip-route-hdr))
  (record-route (:pointer pjsip-rr-hdr))
  (ctype (:pointer pjsip-ctype-hdr))
  (clen (:pointer pjsip-clen-hdr))
  (require (:pointer pjsip-require-hdr))
  (supported (:pointer pjsip-supported-hdr))
  (parse-err (:struct pjsip-parser-err-report)))

(defctype rx-data-msg-info (:struct rx-data-msg-info))

(defcstruct rx-data-endpt-info
  (mod-data (:pointer :void) :count #.+pjsip-max-module+))

(defctype rx-data-endpt-info (:struct rx-data-endpt-info))

(defcstruct (pjsip-rx-data :conc-name pjsip-rx-data-)
  (tp-info (:struct rx-data-tp-info))
  (pkt-info (:struct rx-data-pkt-info))
  (msg-info (:struct rx-data-msg-info))
  (endpt-info (:struct rx-data-endpt-info)))

(defctype pjsip-rx-data (:struct pjsip-rx-data))

(defcstruct pjmedia-stream
  ;;ugly stub for messy struct with bunch of IFDEFs
  (pad :char :count 8192))

(defctype pjmedia-stream (:struct pjmedia-stream))

(defcenum pjmedia-tp-proto
  :pjmedia-tp-proto-none
  :pjmedia-tp-proto-rtp-avp
  :pjmedia-tp-proto-rtp-savp
  :pjmedia-tp-proto-unknown)

(defcenum pjmedia-dir
  :pjmedia-dir-none
  (:pjmedia-dir-encoding 1)
  (:pjmedia-dir-capture 1)
  (:pjmedia-dir-decoding 2)
  (:pjmedia-dir-playback 2)
  (:pjmedia-dir-render 2)
  (:pjmedia-dir-encoding-decoding 3)
  (:pjmedia-dir-capture-playback 3)
  (:pjmedia-dir-capture-render 3))

(defcstruct pjmedia-stream-info
  (type pjmedia-type)
  (proto pjmedia-tp-proto)
  (dir pjmedia-dir)
  (rem-addr pj-sockaddr)
  (rem-rtcp pj-sockaddr)
  (fmt pjmedia-codec-info)
  (param :pointer) ;dangling
  (tx-pt :uint)
  (rx-pt :uint)
  (tx-maxptime :uint)
  (tx-event-pt :int)
  (rx-event-pt :int)
  (ssrc pj-uint32)
  (rtp-ts pj-uint32)
  (rtp-seq pj-uint16)
  (rtp-seq-ts-set :uint8)
  (jb-init :int)
  (jb-min-pre :int)
  (jb-max-pre :int)
  (jb-max :int)
  (rtcp-sdes-bye-disabled pj-bool))

(defctype pjmedia-stream-info (:struct pjmedia-stream-info))

(defcenum pjmedia-sdp-neg-state
  :pjmedia-sdp-neg-state-null
  :pjmedia-sdp-neg-state-local-offer
  :pjmedia-sdp-neg-state-remote-offer
  :pjmedia-sdp-neg-state-wait-nego
  :pjmedia-sdp-neg-state-done)

(defcstruct pjmedia-sdp-neg
  (state pjmedia-sdp-neg-state)
  (prefer-remote-codec-order pj-bool)
  (answer-with-multiple-codecs pj-bool)
  (has-remote-answer pj-bool)
  (answer-was-remote pj-bool)
  (initial-sdp (:pointer (:struct pjmedia-sdp-session)))
  (initial-sdp-tmp (:pointer (:struct pjmedia-sdp-session)))
  (active-local-sdp (:pointer (:struct pjmedia-sdp-session)))
  (active-remote-sdp (:pointer (:struct pjmedia-sdp-session)))
  (neg-local-sdp (:pointer (:struct pjmedia-sdp-session)))
  (neg-remote-sdp (:pointer (:struct pjmedia-sdp-session))))

(defctype pjmedia-sdp-neg (:struct pjmedia-sdp-neg))

(defcenum pjmedia-format-detail-type
  :pjmedia-format-detail-none
  :pjmedia-format-detail-audio
  :pjmedia-format-detail-video
  :pjmedia-format-detail-max)

(defcstruct pjmedia-audio-format-detail
  (clock-rate :uint)
  (channel-count :uint)
  (frame-time-usec :uint)
  (bits-per-sample :uint)
  (avg-bps pj-uint32)
  (max-bps pj-uint32))

(defctype pjmedia-audio-format-detail (:struct pjmedia-audio-format-detail))

(defcstruct pjmedia-rect-size
  (w :uint)
  (h :uint))

(defctype pjmedia-rect-size (:struct pjmedia-rect-size))

(defcstruct pjmedia-ratio
  (num :int)
  (denum :int))

(defctype pjmedia-ratio (:struct pjmedia-ratio))

(defcenum pjmedia-vid-stream-rc-method
  (pjmedia-vid-stream-rc-none 0)
  (pjmedia-vid-stream-rc-simple-blocking 1))

(defcstruct pjmedia-vid-stream-rc-config
  (method pjmedia-vid-stream-rc-method)
  (bandwidth :uint))

(defctype pjmedia-vid-stream-rc-config (:struct pjmedia-vid-stream-rc-config))

(defcstruct pjmedia-video-format-detail
  (size (:struct pjmedia-rect-size))
  (fps (:struct pjmedia-ratio))
  (avg-bps pj-uint32)
  (max-bps pj-uint32))

(defctype pjmedia-vid-dev-index pj-int32)

(defctype pjmedia-video-format-detail (:struct pjmedia-video-format-detail))

(defcunion format-det
  (aud (:struct pjmedia-audio-format-detail))
  (vid (:struct pjmedia-video-format-detail))
  (user :char :count #.+pjmedia-format-detail-user-size+))

(defcstruct pjmedia-format
  (id pj-uint32)
  (type pjmedia-type)
  (detail-type pjmedia-format-detail-type)
  (det (:union format-det)))

(defctype pjmedia-format (:struct pjmedia-format))

(defcstruct pjmedia-port-info
  (name pj-str)
  (signature pj-uint32)
  (dir pjmedia-dir)
  (fmt (:struct pjmedia-format)))

(defctype pjmedia-port-info (:struct pjmedia-port-info))

(defcstruct port-port-data
  (pdata (:pointer :void))
  (ldata :long))

(defctype port-port-data (:struct port-port-data))

(defcstruct pjmedia-port
  (info (:struct pjmedia-port-info))
  (port-data (:struct port-port-data))
  ;;callbackery
  (get-clock-src :pointer)
  (put-frame :pointer)
  (get-frame :pointer)
  (on-destroy :pointer))

(defctype pjmedia-port (:struct pjmedia-port))

(defcstruct pjsip-tx-data-op-key
  (op-key (:struct pj-ioqueue-op-key))
  (tdata :pointer) ;;fwd decl to -tx-data
  (token (:pointer :void))
  (callback :pointer)) ;dangling callbackery

(defctype pjsip-tx-data-op-key (:struct pjsip-tx-data-op-key))

(defcstruct pjsip-buffer
  (start (:pointer :char))
  (cur (:pointer :char))
  (end (:pointer :char)))

(defctype pjsip-buffer (:struct pjsip-buffer))

(defcenum pjsip-transport-type-e
    :pjsip-transport-unspecified
    :pjsip-transport-udp
    :pjsip-transport-tcp
    :pjsip-transport-tls
    :pjsip-transport-sctp
    :pjsip-transport-loop
    :pjsip-transport-loop-dgram
    :pjsip-transport-start-other
    (:pjsip-transport-ipv6 128)
    :pjsip-transport-udp6
    :pjsip-transport-tcp6
    :pjsip-transport-tls6)

(defcstruct server-addresses-entry
  (type pjsip-transport-type-e)
  (priority :uint)
  (weight :uint)
  (addr (:union pj-sockaddr))
  (addr-len :int))

(defcstruct pjsip-server-addresses
  (count :uint)
  (entry (:struct server-addresses-entry) :count #.+pjsip-max-resolved-addresses+))

(defctype pjsip-server-addresses (:struct pjsip-server-addresses))

(defcstruct tx-data-dest-info
  (name pj-str)
  (addr (:struct pjsip-server-addresses))
  (cur-addr :uint))

(defcstruct tx-data-tp-info
  (transport (:pointer (:struct pjsip-transport)))
  (dst-addr (:union pj-sockaddr))
  (dst-addr-len :int)
  (dst-name :char :count #.+pj-inet6-addrstrlen+)
  (dst-port :int))

(defcstruct (pjsip-tx-data :conc-name pjsip-tx-data-)
  (list (:struct pj-list))
  (pool (:pointer (:struct pj-pool)))
  (obj-name :char :count #.+pj-max-obj-name+)
  (info :string)
  (rx-timestamp (:struct pj-time-val))
  (mgr :pointer) ; dangling transport manager
  (op-key (:struct pjsip-tx-data-op-key))
  (lock :pointer) ;dangling lock object
  (msg (:pointer (:struct pjsip-msg)))
  (saved-strict-route (:pointer pjsip-route-hdr))
  (buf (:struct pjsip-buffer))
  (ref-cnt :pointer) ;dangling atomic
  (is-pending :int)
  (token (:pointer :void))
  (cb :pointer) ;callbackery
  (dest-info (:struct tx-data-dest-info))
  (tp-info (:struct tx-data-tp-info))
  (tp-sel (:struct pjsip-tpselector))
  (auth-retry pj-bool)
  (mod-data (:pointer :void) :count #.+pjsip-max-module+)
  (via-addr (:struct pjsip-host-port))
  (via-tp (:pointer :void)))

(defctype pjsip-tx-data (:struct pjsip-tx-data))

(defctype pjsip-user-agent (:struct pjsip-module))

(defcenum pjsip-event-id-e
  :pjsip-event-unknown
  :pjsip-event-timer
  :pjsip-event-tx-msg
  :pjsip-event-rx-msg
  :pjsip-event-transport-error
  :pjsip-event-tsx-state
  :pjsip-event-user)

(defcstruct tsx-body-timer
  (entry (:pointer pj-timer-entry)))

(defcunion tsx-body-tsx-state-src
  (rdata (:pointer pjsip-rx-data))
  (tdata (:pointer pjsip-tx-data))
  (timer (:pointer pj-timer-entry))
  (status pj-status)
  (data (:pointer :void)))

(defcstruct tsx-body-tsx-state
  (src (:union tsx-body-tsx-state-src))
  (tsx :pointer) ;dangling
  (prev-state :int)
  (type pjsip-event-id-e))

(defcstruct tsx-body-tx-msg
  (tdata (:pointer pjsip-tx-data)))

(defcstruct tsx-body-tx-error
  (tdata (:pointer pjsip-tx-data))
  (tsx :pointer)) ;transaction

(defcstruct tsx-body-rx-msg
  (rdata (:pointer pjsip-rx-data)))

(defcstruct tsx-body-user
  (user1 (:pointer :void))
  (user2 (:pointer :void))
  (user3 (:pointer :void))
  (user4 (:pointer :void)))

(defcunion event-tsx-body
  (timer (:struct tsx-body-timer))
  (tsx-state (:struct tsx-body-tsx-state))
  (tx-msg (:struct tsx-body-tx-msg))
  (tx-error (:struct tsx-body-tx-error))
  (rx-msg (:struct tsx-body-rx-msg))
  (user (:struct tsx-body-user)))

(defcstruct pjsip-event
  (list pj-list)
  (type pjsip-event-id-e)
  (body (:union event-tsx-body)))

(defctype pjsip-event (:struct pjsip-event))

(defcenum pjsip-ssl-method
  (:pjsip-ssl-unspecified-method 0)
  (:pjsip-sslv2-method 20)
  (:pjsip-sslv3-method 30)
  (:pjsip-tlsv1-method 31)
  (:pjsip-tlsv1-1-method 32)
  (:pjsip-tlsv1-2-method 33)
  (:pjsip-sslv23-method 23))

(defcenum pj-qos-type
  :pj-qos-type-best-effort
  :pj-qos-type-background
  :pj-qos-type-video
  :pj-qos-type-voice
  :pj-qos-type-control)

(defcenum pj-qos-wmm-prio
  :pj-qos-wmm-prio-bulk-effort
  :pj-qos-wmm-prio-bulk
  :pj-qos-wmm-prio-video
  :pj-qos-wmm-prio-voice)

(defcstruct pj-qos-params
  (flags :uint8)
  (dscp-val :uint8)
  (so-prio :uint8)
  (wmm-proio pj-qos-wmm-prio))

(defctype pj-qos-params (:struct pj-qos-params))

(defcstruct sockopt-params-options
  (level :int)
  (optname :int)
  (optval (:pointer :void))
  (optlen :int))

(defcstruct pj-sockopt-params
  (cnt :uint)
  (options (:struct sockopt-params-options) :count #.+pj-max-sockopt-params+))

(defctype pj-sockopt-params (:struct pj-sockopt-params))

(defcstruct pjsip-tls-setting
  (ca-list-file pj-str)
  (ca-list-path pj-str)
  (cert-file pj-str)
  (privkey-file pj-str)
  (password pj-str)
  (method pjsip-ssl-method)
  (proto pj-uint32)
  (ciphers-num :uint)
  (ciphers :pointer) ;dangling
  (verify-server pj-bool)
  (verify-client pj-bool)
  (require-client-cert pj-bool)
  (timeout pj-time-val)
  (reuse-addr pj-bool)
  (qos-type pj-qos-type)
  (params pj-qos-params)
  (qos-ignore-error pj-bool)
  (sockopt-params pj-sockopt-params)
  (sockopt-ignore-error pj-bool))

(defctype pjsip-tls-setting (:struct pjsip-tls-setting))

(defcstruct pjsip-publishc-opt
  (queue-request pj-bool))

(defcenum pj-turn-tp-type
  (:pj-turn-tp-udp 17)
  (:pj-turn-tp-tcp 6)
  (:pj-turn-tp-tls 255))

(defcenum pj-stun-auth-cred-type
  :pj-stun-auth-cred-static
  :pj-stun-auth-cred-dynamic)

(defcenum pj-stun-passwd-type
  :pj-stun-passwd-plain
  (:pj-stun-passwd-hashed 1))

(defcstruct stun-auth-cred-data-static-cred
  (realm pj-str)
  (username pj-str)
  (data-type pj-stun-passwd-type)
  (data pj-str)
  (nonce pj-str))

(defcstruct stun-auth-cred-data-dyn-cred
  (user-data (:pointer :void))
  (get-auth :pointer)
  (get-cred :pointer)
  (get-password :pointer)
  (verify-nonce :pointer))

(defcunion stun-auth-cred-data
  (static-cred (:struct stun-auth-cred-data-static-cred))
  (dyn-cred (:struct stun-auth-cred-data-dyn-cred)))

(defcstruct pj-stun-auth-cred
  (type pj-stun-auth-cred-type)
  (data (:union stun-auth-cred-data)))

(defctype pj-stun-auth-cred (:struct pj-stun-auth-cred))

(defcstruct pjmedia-vid-stream-sk-config
  (count :uint)
  (interval :uint))

(defctype pjmedia-vid-stream-sk-config (:struct pjmedia-vid-stream-sk-config))

(defcvar "PJ_AF_INET" pj-uint16)

(defcfun "pj_str" (:pointer pj-str) (str :string))
(defcfun "pj_strcpy2" (:pointer pj-str) (pstr (:pointer pj-str)) (cstr :string))
(defcfun "pj_strdup2" (:pointer pj-str) (pool (:pointer pj-pool)) (pstr (:pointer pj-str)) (cstr :string))
(defcfun "pj_init" pj-status)
(defcfun "pj_log_set_level" :void (log-level :int))
(defcfun "pj_log_set_log_func" :void (func :pointer))
(defcfun "pj_log" :void (sender :string) (level :int) (format :string)) ;silently dropping va_list
(defcfun "pj_log_pop_indent" :void)

(defcfun "pjlib_util_init" pj-status)

(defcvar "pj_pool_factory_default_policy" pj-pool-factory-policy)

(defcfun "pj_pool_factory_get_default_policy" (:pointer pj-pool-factory-policy))

(defcfun "pj_caching_pool_init" :void (cp (:pointer pj-caching-pool)) 
	 (factory-default-policy (:pointer pj-pool-factory-policy)) (max-capacity size))

(defcfun "pjsip_endpt_create" pj-status (factory (:pointer pj-pool-factory)) (endpt-name :string) 
	 (endpoint (:pointer pjsip-endpoint)))

(defcfun "pj_sockaddr_init" :void (family :int) (addr (:pointer pj-sockaddr)) (cp :pointer) (port :uint))

(defcfun "pjsip_udp_transport_start" pj-status (endpoint (:pointer pjsip-endpoint))
	 (local-addr (:pointer pj-sockaddr-in))
	 (hostport (:pointer pjsip-host-port))
	 (async-cnt :uint) (p_transport (:pointer (:pointer pjsip-transport))))

(defcfun "pjsip_udp_transport_start6" pj-status (endpoint (:pointer pjsip-endpoint))
	 (local-addr (:pointer pj-sockaddr-in6))
	 (hostport (:pointer pjsip-host-port))
	 (async-cnt :uint) (p_transport (:pointer (:pointer pjsip-transport))))

(defcfun "pjsip_tsx_layer_init_module" pj-status (endpoint (:pointer pjsip-endpoint)))

(defcfun "pjsip_ua_init_module" pj-status (endpoint (:pointer pjsip-endpoint)) 
	 (prm (:pointer pjsip-ua-init-param)))

(defcfun "pjsip_inv_create_uac" pj-status (dlg (:pointer pjsip-dialog)) (local-sdp (:pointer pjmedia-sdp-session))
	 (options :uint) (p-inv (:pointer (:pointer pjsip-inv-session))))

(defcfun "pjsip_inv_usage_init" pj-status (endpoint (:pointer pjsip-endpoint)) (cb (:pointer pjsip-inv-callback)))

(defcfun "pjsip_inv_invite" pj-status (inv (:pointer pjsip-inv-session)) (p-tdata :pointer (:pointer)))

(defcfun "pjsip_inv_send_msg" pj-status (inv (:pointer pjsip-inv-session)) (tdata :pointer))

(defcfun "pjsip_100rel_init_module" pj-status (endpoint (:pointer pjsip-endpoint)))

(defcfun "pjsip_endpt_register_module" pj-status (endpoint (:pointer pjsip-endpoint))
	 (module (:pointer pjsip-module)))

(defcfun "pjsip_endpt_handle_events" pj-status (endpt (:pointer pjsip-endpoint)) (max-timeout (:pointer pj-time-val)))

(defcfun "pjsip_endpt_respond_stateless" pj-status (endpt (:pointer pjsip-endpoint)) (rdata (:pointer pjsip-rx-data))
	 (st-code :int) (st-text (:pointer pj-str)) (hdr-list (:pointer pjsip-hdr)) (body (:pointer pjsip-msg-body)))

(defcfun "pjsip_endpt_get_ioqueue" :pointer (endpt (:pointer pjsip-endpoint)))

(defcfun "pjmedia_codec_g711_init" pj-status (endpoint (:pointer pjmedia-endpt)))

(defcfun "pjmedia_transport_udp_create3" pj-status (endpoint (:pointer pjmedia-endpt)) (af :int) (name :string) (addr (:pointer pj-str))
	 (port :int) (options :uint) (p-tp (:pointer (:pointer pjmedia-transport))))

(defcfun "pjsip_dlg_create_uac" pj-status (ua (:pointer pjsip-user-agent)) (local-uri (:pointer pj-str))
	 (local-contact (:pointer pj-str)) (remote-uri (:pointer pj-str)) (target (:pointer pj-str))
	 (p-dlg (:pointer (:pointer pjsip-dialog))))

(defcfun "pjmedia_endpt_create_sdp" pj-status (endpoint (:pointer pjmedia-endpt)) (pool (:pointer pj-pool))
	 (stream-cnt :uint) (sock-info (:pointer pjmedia-sock-info)) (p-sdp (:pointer (:pointer pjmedia-sdp-session))))

(defcfun "pjmedia_sdp_neg_get_active_local" pj-status (neg (:pointer pjmedia-sdp-neg))
	 (local (:pointer (:pointer pjmedia-sdp-session))))

(defcfun "pjmedia_sdp_neg_get_active_remote" pj-status (neg (:pointer pjmedia-sdp-neg))
	 (remote (:pointer (:pointer pjmedia-sdp-session))))

(defcfun "pjmedia_stream_info_from_sdp" pj-status (info (:pointer pjmedia-stream-info)) (pool (:pointer pj-pool))
	 (endpt (:pointer pjmedia-endpt)) (local (:pointer pjmedia-sdp-session))
	 (remote (:pointer pjmedia-sdp-session)) (stream-idx :uint))

(defcfun "pjmedia_stream_create" pj-status (endpt (:pointer pjmedia-endpt)) (pool (:pointer pj-pool))
	 (info (:pointer pjmedia-stream-info)) (tp (:pointer pjmedia-transport))
	 (user-data (:pointer :void)) (p-stream (:pointer (:pointer pjmedia-stream))))

(defcfun "pjmedia_stream_start" pj-status (stream (:pointer pjmedia-stream)))

(defcfun "pjmedia_stream_destroy" pj-status (stream (:pointer pjmedia-stream)))

(defcfun "pjmedia_stream_get_port" pj-status (stream (:pointer pjmedia-stream)) (p-port (:pointer (:pointer pjmedia-port))))

(defcfun "pjsip_endpt_destroy" pj-status (endpt (:pointer pjsip-endpoint)))

(defcfun "pj_pool_release" :void (pool (:pointer pj-pool)))

(defcfun "pjsip_get_status_text" (:pointer pj-str) (code :int))

(defcfun "pjsip_inv_state_name" :string (state pjsip-inv-state))

(defcfun "pjsip_inv_verify_request" pj-status (rdata (:pointer pjsip-rx-data)) (options (:pointer :uint))
	 (l-sdp (:pointer pjmedia-sdp-session)) (dlg (:pointer pjsip-dialog))
	 (endpt (:pointer pjsip-endpoint)) (p-tdata (:pointer (:pointer pjsip-tx-data))))

(defcfun "pjsip_dlg_create_uas_and_inc_lock" pj-status (ua (:pointer pjsip-user-agent)) (rdata (:pointer pjsip-rx-data))
	 (contact (:pointer pj-str)) (p-dlg (:pointer (:pointer pjsip-dialog))))

(defcfun "pjsip_dlg_inc_lock" :void (dlg (:pointer pjsip-dialog)))
(defcfun "pjsip_dlg_try_inc_lock" pj-status (dlg (:pointer pjsip-dialog)))
(defcfun "pjsip_dlg_dec_lock" :void (dlg (:pointer pjsip-dialog)))

(defcfun "pjsip_inv_create_uas" pj-status (dlg (:pointer pjsip-dialog)) (rdata (:pointer pjsip-rx-data))
	 (local-sdp (:pointer pjmedia-sdp-session)) (options :uint) (p-inv (:pointer (:pointer pjsip-inv-session))))

(defcfun "pjsip_inv_initial_answer" pj-status (inv (:pointer pjsip-inv-session)) (rdata (:pointer pjsip-rx-data))
	 (st-code :int) (st-text (:pointer pj-str)) (sdp (:pointer pjmedia-sdp-session))
	 (p-session (:pointer (:pointer pjmedia-sdp-session))))

(defcfun "pjsip_inv_answer" pj-status (inv (:pointer pjsip-inv-session)) (st-code :int) (st-text (:pointer pj-str))
	 (local-sdp (:pointer pjmedia-sdp-session)) (p-session (:pointer (:pointer pjmedia-sdp-session))))

(defcfun "pj_gethostip" pj-status (af :int) (addr (:pointer pj-sockaddr)))

(defcfun "pj_sockaddr_print" :string (addr (:pointer pj-sockaddr)) (buf :string) (size :int) (flags :uint))

(defcfun "pjsip_ua_instance" (:pointer pjsip-user-agent))

(defcfun "pjsip_tpmgr_destroy" pj-status (mgr :pointer))

(defcfun "pjmedia_endpt_create2" pj-status (pf (:pointer pj-pool-factory)) (ioqueue :pointer) (worker-cnt :uint)
	 (p-endpt (:pointer (:pointer pjmedia-endpt))))

(defcfun "pjmedia_endpt_destroy2" pj-status (endpt (:pointer pjmedia-endpt)))

(defcfun "bzero" :void (s (:pointer :void)) (n size))

(defcfun "pjsip_rx_data_get_info" (:pointer :char) (rdata (:pointer pjsip-rx-data)))

(defcfun "pjsip_tx_data_get_info" (:pointer :char) (tdata (:pointer pjsip-tx-data)))

(defcfun "pjsip_rdata_get_dlg" (:pointer pjsip-dialog) (rdata (:pointer pjsip-rx-data)))

;;; Implementing these as PJSIP guys made them inlined in C..
(defun pjmedia-endpt-create (pf ioqueue worker-cnt p-endpt)
  (if (pj-success (pjmedia-aud-subsys-init pf))
      (if (pj-success (pjmedia-endpt-create2 pf ioqueue worker-cnt p-endpt))
	  +pj-success+
	  (progn (pjmedia-aud-subsys-shutdown) 1))
      1))

(defun pjmedia-endpt-destroy (endpt)
  (prog1 (pjmedia-endpt-destroy2 endpt)
    (pjmedia-aud-subsys-shutdown)))

(defun pjmedia-transport-info-init (info)
  ;; we comment bzero out altogher until we find what's going on
  (bzero info (foreign-type-size 'pjmedia-transport-info))
  (setf (foreign-slot-value (foreign-slot-pointer info 'pjmedia-transport-info 'sock-info) 'pjmedia-sock-info 'rtp-sock) +pj-invalid-socket+
	(foreign-slot-value (foreign-slot-pointer info 'pjmedia-transport-info 'sock-info) 'pjmedia-sock-info 'rtcp-sock) +pj-invalid-socket+))

(defun pjmedia-transport-get-info (tp info)
  (if (and (not (null-pointer-p tp))
	   (not (null-pointer-p (foreign-slot-value tp 'pjmedia-transport 'op)))
	   (not (null-pointer-p (foreign-slot-value (foreign-slot-value tp 'pjmedia-transport 'op) 'pjmedia-transport-op 'get-info))))
      (foreign-funcall-pointer (foreign-slot-value (foreign-slot-value tp 'pjmedia-transport 'op) 'pjmedia-transport-op 'get-info) ()
			       :pointer tp :pointer info
			       pj-status)
      +pj-enotsup+))

(defun pjmedia-transport-close (tp)
  (if (not (null-pointer-p (foreign-slot-value (foreign-slot-value tp 'pjmedia-transport 'op)
					       'pjmedia-transport-op 'destroy)))
      (foreign-funcall-pointer (foreign-slot-value (foreign-slot-value tp 'pjmedia-transport 'op) 'pjmedia-transport-op 'destroy) ()
			       :pointer tp pj-status)
      +pj-success+))


(defun pj-cstr (pjstring string)
  (with-foreign-slots ((ptr slen) pjstring pj-str)
    (setf slen (length string))
    (setf ptr (foreign-string-alloc string))
    pjstring))

(defcallback logger :void ((level :int) (data :string) (len :int))
  (declare (ignorable len level))
  (format t "~A" data))

(defun ua-log (string)
  (pj-log "cl-pjsip-ua.lisp" 1 string)
  (finish-output))

(defun deref (var)
  (mem-ref var :pointer))

(defun pjsip-uri-print (context uri)
  (with-foreign-object (buffer :char 256) 
    (foreign-funcall-pointer (foreign-slot-value uri 'pjsip-uri-vptr 'cl-pjsip::p-print) ()
			     pjsip-uri-context-e context :pointer uri (:pointer :char) buffer :int 256 :int)
    (foreign-string-to-lisp buffer)))

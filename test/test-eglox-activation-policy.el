;;; test-eglox-activation-policy.el --- Tests for dormant activation policy -*- lexical-binding: t; -*-

;;; Commentary:
;; Unit tests for `eglox-activation-policy', `eglox-dormant-buffers',
;; and `eglox-warm-project'.

;;; Code:

(require 'ert)
(require 'eglox)

(ert-deftest eglox-test-policy-nil-unchanged ()
  "When `eglox-activation-policy' is nil, `eglox-ensure' calls `eglot-ensure' immediately."
  (let ((ensured nil)
        (eglox-activation-policy nil)
        (eglox-dormant-buffers nil))
    (cl-letf (((symbol-function 'eglox--init-eglot) #'ignore)
              ((symbol-function 'eglot-ensure) (lambda () (setq ensured t))))
      (with-temp-buffer
        (eglox-ensure)
        (should (eq ensured t))
        (should (null eglox-dormant-buffers))))))

(ert-deftest eglox-test-policy-when-visible-hidden-buffer ()
  "When policy is `when-visible' and buffer is hidden, buffer is marked dormant without eglot."
  (let ((ensured nil)
        (eglox-activation-policy 'when-visible)
        (eglox-dormant-buffers nil))
    (cl-letf (((symbol-function 'eglox--init-eglot) #'ignore)
              ((symbol-function 'eglot-ensure) (lambda () (setq ensured t)))
              ((symbol-function 'get-buffer-window) (lambda (&rest _) nil)))
      (with-temp-buffer
        (eglox-ensure)
        (should (null ensured))
        (should (memq (current-buffer) eglox-dormant-buffers))))))

(ert-deftest eglox-test-policy-when-visible-displayed-buffer ()
  "When policy is `when-visible' and buffer is displayed, `eglot-ensure' is called."
  (let ((ensured nil)
        (eglox-activation-policy 'when-visible)
        (eglox-dormant-buffers nil))
    (cl-letf (((symbol-function 'eglox--init-eglot) #'ignore)
              ((symbol-function 'eglot-ensure) (lambda () (setq ensured t)))
              ((symbol-function 'get-buffer-window) (lambda (&rest _) (selected-window))))
      (with-temp-buffer
        (eglox-ensure)
        (should (eq ensured t))
        (should (null eglox-dormant-buffers))))))

(ert-deftest eglox-test-display-dormant-buffer-activates ()
  "Displaying a dormant buffer triggers activation via `eglox-activate-dormant-visible'."
  (let* ((ensured-buffers nil)
         (test-buf (generate-new-buffer " *eglox-dormant-test*"))
         (eglox-dormant-buffers (list test-buf)))
    (unwind-protect
        (cl-letf (((symbol-function 'eglot-ensure)
                   (lambda () (push (current-buffer) ensured-buffers))))
          (let ((win (selected-window)))
            (cl-letf (((symbol-function 'window-list) (lambda (&rest _) (list win)))
                      ((symbol-function 'window-buffer) (lambda (&rest _) test-buf)))
              (eglox-activate-dormant-visible win)
              (should (memq test-buf ensured-buffers))
              (should (not (memq test-buf eglox-dormant-buffers))))))
      (when (buffer-live-p test-buf)
        (kill-buffer test-buf)))))

(ert-deftest eglox-test-warm-project-activates-first ()
  "Warm projects activates the first hidden buffer of an unwarmed project."
  (let* ((ensured nil)
         (eglox-warm-projects 1)
         (eglox-warmed-projects nil)
         (test-buf (generate-new-buffer " *eglox-warm-test*")))
    (unwind-protect
        (cl-letf (((symbol-function 'project-current) (lambda (&rest _) '(project . "/dummy/root/")))
                  ((symbol-function 'project-root) (lambda (_) "/dummy/root/"))
                  ((symbol-function 'eglot-ensure) (lambda () (setq ensured t))))
          (with-current-buffer test-buf
            (setq buffer-file-name "/dummy/root/foo.go")
            (should (eglox-warm-project test-buf))
            (should (eq ensured t))
            (should (equal eglox-warmed-projects '("/dummy/root/")))
            ;; Second call for same project does not warm again
            (setq ensured nil)
            (should (null (eglox-warm-project test-buf)))
            (should (null ensured))))
      (when (buffer-live-p test-buf)
        (kill-buffer test-buf)))))

(provide 'test-eglox-activation-policy)
;;; test-eglox-activation-policy.el ends here

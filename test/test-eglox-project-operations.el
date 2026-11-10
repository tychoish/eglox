;;; test-eglox-project-operations.el --- Project operation tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'projectile)
(require 'eglox-project)

(defun project-test--wait (pred)
  "Spin the event loop until PRED is non-nil or 3s elapse."
  (let ((start (float-time)))
    (while (and (not (funcall pred)) (< (- (float-time) start) 3.0))
      (sit-for 0.01))))

(ert-deftest project-projectile/run-incrementally-counts-handled-items ()
  "on-done receives the number of items for which FN returned non-nil."
  (let ((done nil)
        (seen nil))
    (cl-letf (((symbol-function 'message) #'ignore))
      (projectile--run-incrementally
       (lambda (item) (push item seen) (cl-oddp item))
       '(1 2 3 4 5)
       :label "test" :on-done (lambda (n) (setq done n)))
      (project-test--wait (lambda () done)))
    (should (equal done 3))
    (should (equal (nreverse seen) '(1 2 3 4 5)))))

(ert-deftest project-projectile/load-project-buffers-errors ()
  "Signal `user-error' with no root, or with no files."
  (cl-letf (((symbol-function 'projectile-project-root) (lambda (&optional _) nil)))
    (should-error (projectile-load-project-buffers) :type 'user-error))
  (cl-letf (((symbol-function 'projectile-project-files) (lambda (_) nil)))
    (should-error (projectile-load-project-buffers "/tmp/") :type 'user-error)))

(ert-deftest project-projectile/session-restore-async-recreates-buffers ()
  "Each saved buffer is recreated and the window state is restored once."
  (let ((done nil)
        (recreated nil)
        (window-put nil)
        (original-window (frame-root-window (selected-frame))))
    (cl-letf (((symbol-function 'message) #'ignore)
              ((symbol-function 'projectile-session--read)
               (lambda (_) (list :buffers '(a b) :window-state 'ws)))
              ((symbol-function 'projectile-session--recreate-buffer)
               (lambda (saved) (push saved recreated) (current-buffer)))
              ((symbol-function 'projectile-session--sanitize-window-state) #'identity)
              ((symbol-function 'window-state-put) (lambda (&rest args) (setq window-put args))))
      (projectile-session-restore-async "/fake/" :on-done (lambda (n) (setq done n)))
      (project-test--wait (lambda () done)))
    (should (equal done 2))
    (should (equal (nreverse recreated) '(a b)))
    (should (eq (car window-put) 'ws))
    (should (eq (cadr window-put) original-window))))

(ert-deftest project-projectile/session-restore-async-no-session ()
  "Without saved data, noninteractive calls are silent no-ops."
  (cl-letf (((symbol-function 'projectile-session--read) (lambda (_) nil)))
    (should-not (projectile-session-restore-async "/fake/"))))


(provide 'test-eglox-project-operations)
;;; test-eglox-project-operations.el ends here

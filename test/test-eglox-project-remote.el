;;; test-eglox-project-remote.el --- Project cache identity tests -*- lexical-binding: t; -*-

;;; Commentary:
;; Exercise remote identity and cross-instance persistent cache paths.

;;; Code:
(require 'ert)
(require 'cl-lib)
(require 'eglox-project)

(defun eglox-project-test--remote-handler (operation &rest args)
  "Permit only lexical filename OPERATION on ARGS, rejecting remote I/O."
  (unless (memq operation '(expand-file-name directory-file-name file-remote-p))
    (error "Unexpected remote file operation: %S" operation))
  (let ((inhibit-file-name-handlers
         (cons 'eglox-project-test--remote-handler
               (and (eq inhibit-file-name-operation operation)
                    inhibit-file-name-handlers)))
        (inhibit-file-name-operation operation))
    (apply operation args)))

(ert-deftest eglox-project/remote-cache-identity-without-io ()
  (let ((eglox-project-cache-directory (make-temp-file "eglox-remote-cache-" t))
        (file-name-handler-alist
         (cons '("\\`/ssh:" . eglox-project-test--remote-handler)
               file-name-handler-alist)))
    (unwind-protect
        (let ((first (eglox-project--cache-file nil "/ssh:host:/srv/team/project/")))
          (should (equal first (eglox-project--cache-file nil "/ssh:host:/srv/team/project")))
          (should-not (equal first (eglox-project--cache-file nil "/ssh:host:/srv/other/project/")))
          (should-not (equal first (eglox-project--cache-file nil "/ssh:other:/srv/team/project/")))
          (should (file-in-directory-p first eglox-project-cache-directory)))
      (delete-directory eglox-project-cache-directory t))))

(ert-deftest eglox-project/cache-persists-across-instances ()
  (let* ((eglox-project-cache-directory (make-temp-file "eglox-instance-cache-" t))
         (projectile-enable-caching 'persistent)
         (projectile-projects-cache (make-hash-table :test #'equal))
         (root "/ssh:host:/srv/team/project/")
         (sprite-instance-id "instance-one")
         (file-name-handler-alist
          (cons '("\\`/ssh:" . eglox-project-test--remote-handler)
                file-name-handler-alist))
         (files '("src/a.py" "src/b.py")))
    (unwind-protect
        (cl-letf (((symbol-function 'projectile-project-cache-file)
                   (lambda (&optional project-root)
                     (eglox-project--cache-file nil project-root))))
          (let ((first (projectile-project-cache-file root)))
            (projectile-cache-project root files)
            (setq sprite-instance-id "instance-two")
            (should (equal first (projectile-project-cache-file root)))
            (should (equal files (projectile-load-project-cache root)))
            (should-not (equal first (projectile-project-cache-file
                                      "/ssh:host:/srv/other/project/")))))
      (delete-directory eglox-project-cache-directory t))))

(provide 'test-eglox-project-remote)
;;; test-eglox-project-remote.el ends here

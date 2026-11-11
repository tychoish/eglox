;;; test-eglox-defaults.el --- Settings lifecycle tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Check configuration settings and restoration.
;;; Code:
(require 'ert)
(require 'cl-lib)
(require 'eglox)

(defvar eglox-test-setting 'original)
(defvar yaml-pro-mode)
(defvar builder-elisp-mode)

(ert-deftest eglox-settings-apply-and-restore ()
  (let ((eglox-test-setting 'original)
        (eglox-settings '((eglox-test-setting . nil)
                          (eglox-test-unbound . new)))
        (eglox--saved-settings nil))
    (unwind-protect
        (progn
          (makunbound 'eglox-test-unbound)
          (eglox--apply-settings)
          (should-not (default-value 'eglox-test-setting))
          (should (eq (default-value 'eglox-test-unbound) 'new))
          (eglox--restore-settings)
          (should (eq (default-value 'eglox-test-setting) 'original))
          (should-not (default-boundp 'eglox-test-unbound)))
      (eglox--restore-settings)
      (makunbound 'eglox-test-unbound))))

(ert-deftest eglox-global-mode-rolls-back-on-error ()
  "A failed activation releases the project integration it acquired."
  (let ((eglox-global-mode nil)
        (eglox--global-active nil)
        (eglox--owns-project-mode nil)
        (eglox-project-mode nil))
    (cl-letf (((symbol-function 'eglox-project-mode)
               (lambda (arg) (setq eglox-project-mode (> arg 0))))
              ((symbol-function 'eglox--apply-settings)
               (lambda (&rest _) (error "test failure"))))
      (should-error (eglox-global-mode 1))
      (should-not eglox-global-mode)
      (should-not eglox--global-active)
      (should-not eglox-project-mode)
      (should-not eglox--owns-project-mode))))

(ert-deftest eglox-local-mode-setups ()
  (with-temp-buffer
    (eglox--go-setup)
    (should (= fill-column eglox-go-fill-column))
    (should-not compilation-error-screen-columns))
  (with-temp-buffer
    (eglox--python-setup)
    (should (= fill-column eglox-python-fill-column))
    (should (= tab-width eglox-python-tab-width)))
  (with-temp-buffer
    (let ((buffer-file-name "/tmp/example.rs"))
      (eglox--rustic-setup)
      (should-not compilation-ask-about-save)))
  (let ((eglox-enable-yaml-pro t)
        (yaml-pro-mode nil))
    (cl-letf (((symbol-function 'yaml-pro-mode)
               (lambda (arg) (setq-local yaml-pro-mode (> arg 0)))))
      (with-temp-buffer
        (eglox--yaml-setup)
        (should (= tab-width eglox-yaml-tab-width))
        (should yaml-pro-mode))))
  (let ((eglox-enable-builder-elisp t)
        (builder-elisp-mode nil))
    (cl-letf (((symbol-function 'builder-elisp-mode)
               (lambda (arg) (setq-local builder-elisp-mode (> arg 0)))))
      (with-temp-buffer
        (eglox--elisp-setup)
        (should builder-elisp-mode)))))

(defvar eglox-test-hook-a nil)
(defvar eglox-test-hook-b nil)

(ert-deftest eglox-modes-merge-and-initialize ()
  (let* ((current '(("\\.py\\'" . python-mode)
                    ("\\.el\\'" . emacs-lisp-mode)))
         (new '(("\\.py\\'" . python-ts-mode)
                ("\\.go\\'" . go-ts-mode)))
         (merged (eglox-modes-merge-alist current new)))
    (should (equal merged
                   '(("\\.py\\'" . python-ts-mode)
                     ("\\.go\\'" . go-ts-mode)
                     ("\\.el\\'" . emacs-lisp-mode)))))
  (let ((auto-mode-alist '(("\\.py\\'" . python-mode))))
    (eglox-modes-initialize)
    (should (eq (cdr (assoc "\\.py\\'" auto-mode-alist)) 'python-ts-mode))
    (should (eq (cdr (assoc "\\.rs\\'" auto-mode-alist)) 'rustic-mode))))

(ert-deftest eglox-configurable-mode-hooks ()
  (let ((eglox-test-hook-a nil)
        (eglox-test-hook-b nil)
        (eglox-mode-hooks '((eglox-test-hook-a . eglox-ensure)
                            (eglox-test-hook-b . (eglox--go-setup eglox-ensure)))))
    (eglox--add-hooks)
    (should (equal eglox-test-hook-a '(eglox-ensure)))
    (should (equal (sort (copy-sequence eglox-test-hook-b) #'string<)
                   '(eglox--go-setup eglox-ensure)))
    (eglox--remove-hooks)
    (should-not eglox-test-hook-a)
    (should-not eglox-test-hook-b)))

(provide 'test-eglox-defaults)
;;; test-eglox-defaults.el ends here

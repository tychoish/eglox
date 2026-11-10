;;; test-eglox-language.el --- Language integration tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'eglox)
(defvar python-base-mode-map)

(ert-deftest eglox-language/python-bindings-before-and-after-load ()
  "Python bindings apply whether its map exists before or after activation."
  (dolist (map-available '(t nil))
    (let ((eglox-global-mode t)
          (eglox--python-keys nil)
          (python-base-mode-map (and map-available (make-sparse-keymap)))
          (installed 0))
      (cl-letf (((symbol-function 'font-lock-add-keywords)
                 (lambda (&rest _) (setq installed (1+ installed)))))
        (when map-available (eglox--configure-python))
        (unless map-available
          (setq python-base-mode-map (make-sparse-keymap))
          ;; Simulate the callback registered with `with-eval-after-load'.
          (eglox--configure-python))
        (eglox--configure-python)
        (should (= installed 1))
        (should (eq (lookup-key python-base-mode-map (kbd "M-<left>"))
                    #'python-indent-shift-left))
        (should (eq (lookup-key python-base-mode-map (kbd "M-<right>"))
                    #'python-indent-shift-right))))))

(ert-deftest eglox-language/buffer-setup-and-opt-outs ()
  (let ((eglox-go-fill-column 88)
        (eglox-python-fill-column 91)
        (eglox-python-tab-width 3)
        (eglox-yaml-tab-width 6)
        (eglox-enable-yaml-pro t)
        (eglox-enable-builder-elisp t)
        (yaml-calls 0)
        (builder-calls 0))
    (cl-letf (((symbol-function 'yaml-pro-mode)
               (lambda (_) (setq yaml-calls (1+ yaml-calls))))
              ((symbol-function 'builder-elisp-mode)
               (lambda (_) (setq builder-calls (1+ builder-calls)))))
      (with-temp-buffer
        (eglox--go-setup)
        (should (= fill-column 88))
        (should (local-variable-p 'compilation-error-screen-columns))
        (should-not compilation-error-screen-columns))
      (with-temp-buffer
        (eglox--python-setup)
        (should (= fill-column 91))
        (should (= tab-width 3)))
      (with-temp-buffer
        (eglox--yaml-setup)
        (should (= tab-width 6)))
      (with-temp-buffer
        (eglox--rustic-setup)
        (should-not (local-variable-p 'compilation-ask-about-save))
        (setq buffer-file-name "/tmp/example.rs")
        (eglox--rustic-setup)
        (should (local-variable-p 'compilation-ask-about-save))
        (should-not compilation-ask-about-save))
      (with-temp-buffer (eglox--elisp-setup))
      (setq eglox-enable-yaml-pro nil eglox-enable-builder-elisp nil)
      (with-temp-buffer (eglox--yaml-setup) (eglox--elisp-setup))
      (should (= yaml-calls 1))
      (should (= builder-calls 1)))))

(ert-deftest eglox-language/deferred-language-settings ()
  (let ((eglox--saved-settings nil)
        (eglox-settings '((rustic-lsp-client . custom-client)
                          (terraform-indent-level . 5)
                          (web-mode-code-indent-offset . 7))))
    (unwind-protect
        (progn
          (eglox--apply-settings)
          ;; A library's defvar leaves the preconfigured value intact.
          (eval '(defvar rustic-lsp-client 'library-default))
          (eval '(defvar terraform-indent-level 2))
          (eval '(defvar web-mode-code-indent-offset 2))
          (should (eq (default-value 'rustic-lsp-client) 'custom-client))
          (should (= (default-value 'terraform-indent-level) 5))
          (should (= (default-value 'web-mode-code-indent-offset) 7)))
      (eglox--restore-settings))))

(provide 'test-eglox-language)
;;; test-eglox-language.el ends here

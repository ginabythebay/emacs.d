;;; package --- Summary --- Gina Whites Emacs initialization

;;; Commentary:
;;; Stuff here

;;; Code:

;; Get all this machine-written custom crud out of my cleanish init.el file.
;; See http://emacsblog.org/2008/12/06/quick-tip-detaching-the-custom-file/
(setq custom-file "~/.emacs.d/custom.el")
(load custom-file 'noerror)

(require 'package)
(setq package-enable-at-startup nil)
(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/"))

(package-initialize)

;; Bootstrap `use-package'
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(use-package yasnippet
  :ensure t
  :config (setq yas-global-mode 1))

(use-package which-key
  :ensure t
  :config (which-key-mode))

(use-package go-autocomplete
  :ensure t)

;; Configure golint if it is installed
(let ((lint-path (eval-and-compile (concat (getenv "GOPATH")  "/src/github.com/golang/lint/misc/emacs"))))
  (use-package golint
    :if (and (getenv "GOPATH") (file-exists-p lint-path))
    :load-path lint-path))

(use-package flycheck
  :ensure t
  :config (global-flycheck-mode))

(use-package js2-mode
  :ensure t
  :mode ("\\.js\\'" . js2-mode)
  :config (setq js-indent-level 2))

(use-package markdown-mode
  :ensure t
  :mode ("\\.md\\'" . markdown-mode)
  :config (let ((mm "/usr/local/bin/multimarkdown"))
	    (when (file-exists-p mm)
	      (setq markdown-command mm))))

(use-package magit
  :ensure t
  :bind ("C-x g" . magit-status))


;; C
(setq c-default-style "stroustrup"
      c-basic-offset 2)
(setq c-default-style "whitesmith"
      c-basic-offset 2)

;; Python
(setq c-default-style "python"
      c-basic-offset 2)

;; Java
(setq c-default-style "java"
      c-basic-offset 2)

(delete-selection-mode t)
(setq column-number-mode t)  ;; put line number in mode line.

;; (add-to-list 'load-path "~/.emacs.d/lisp/")



;; (set-face-attribute 'default nil :height 130)

;; ;(require 'go-mode-load)
;; (require 'go-mode-autoloads)
;; (require 'auto-highlight-symbol)

;; (setq ahs-modes (cons `go-mode ahs-modes))
;; (global-auto-highlight-symbol-mode t)

;; (add-hook 'c-mode-hook
;;           (lambda ()
;; 	    (gtags-mode 1)))

;; (add-hook 'go-mode-hook
;;           (lambda ()
;; 	    (define-key go-mode-map (kbd "C-c C-c") 'compile)
;;             (add-hook 'before-save-hook 'gofmt-before-save)
;;             (setq tab-width 4)
;; 	    (gtags-mode 1)
;;             (setq indent-tabs-mode 1)))

;; (smartparens-global-mode t)

;; (require 'web-mode)
;; (add-to-list 'auto-mode-alist '("\\.phtml\\'" . web-mode))
;; (add-to-list 'auto-mode-alist '("\\.tpl\\.php\\'" . web-mode))
;; (add-to-list 'auto-mode-alist '("\\.jsp\\'" . web-mode))
;; (add-to-list 'auto-mode-alist '("\\.as[cp]x\\'" . web-mode))
;; (add-to-list 'auto-mode-alist '("\\.erb\\'" . web-mode))
;; (add-to-list 'auto-mode-alist '("\\.mustache\\'" . web-mode))
;; (add-to-list 'auto-mode-alist '("\\.djhtml\\'" . web-mode))
;; (add-to-list 'auto-mode-alist '("\\.html?\\'" . web-mode))


;; (defvar home-buffer nil
;;        "The buffer currently designated as home")

;; (defun set-current-buffer-to-home-buffer () 
;;   "Saves the current buffer as the home buffer"
;;   (interactive)
;;   (setq home-buffer (current-buffer))
;;   (message "Home buffer was set to %s" home-buffer))

;; (defun switch-to-home-buffer ()
;;   "Switches to the home buffer"
;;   (interactive)
;;   (switch-to-buffer home-buffer))

;; (global-set-key [f11] 'switch-to-home-buffer)
;; (global-set-key [(control f11)] 'set-current-buffer-to-home-buffer)

;; (setq gofmt-command "goimports")

;; (custom-set-faces
;;  ;; custom-set-faces was added by Custom.
;;  ;; If you edit it by hand, you could mess it up, so be careful.
;;  ;; Your init file should contain only one such instance.
;;  ;; If there is more than one, they won't work right.
;;  )

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;; deft                                                                   ;;
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; (require 'deft)
;; (setq deft-directory "/home/gina/docs/deft")
;; (setq deft-extension "org")
;; (setq deft-text-mode 'org-mode)
;; (setq deft-use-filename-as-title t)
;; (setq deft-auto-save-interval 0)
;; ;;key to launch deft
;; (global-set-key (kbd "C-c d") 'deft)

;; (server-start)

(provide 'init)
;;; init.el ends here


 
;; SKIP?
;; (add-to-list 'load-path "~/.emacs.d/lisp")
;; (require 'auto-complete-config)
;; (add-to-list 'ac-dictionary-directories "~/.emacs.d/ac-dict")
;; (ac-config-default)




;; ;;; Stefan Monnier <foo at acm.org>. It is the opposite of fill-paragraph    
;; (defun unfill-paragraph ()
;;   "Takes a multi-line paragraph and makes it into a single line of text."
;;   (interactive)
;;   (let ((fill-column (point-max)))
;;     (fill-paragraph nil)))

;; (defun toggle-line-move-visual ()
;;   "Toggle behavior of up/down arrow key, by visual line vs logical line."
;;   (interactive)
;;   (if line-move-visual
;;       (setq line-move-visual nil)
;;     (setq line-move-visual t))
;;   )

;; (defun switch-to-other-buffer () 
;;   "Switches to the most recent buffer"
;;   (interactive)
;;   (switch-to-buffer (other-buffer t)))
;; (global-set-key [f2] 'switch-to-other-buffer)
;; (global-set-key "\C-f" 'fill-paragraph)

;;; minitest.el --- An Emacs mode for ruby minitest files

;; Copyright © 2013 Arthur Nogueira Neves

;; Author: Arthur Neves
;; URL: https://github.com/arthurnn/minitest-emacs
;; Version: 0.3
;; Package-Requires: ((dash "1.0.0"))

;; This file is NOT part of GNU Emacs.

;;; Code:

(require 'dash)
(require 'ansi-color)

(defcustom minitest-keymap-prefix (kbd "C-c ,")
  "Minitest keymap prefix."
  :group 'minitest
  :type 'string)

(defcustom minitest-use-zeus-when-possible t
  "When t and .zeus.sock is present, run specs with 'zeus'."
  :type 'boolean
  :group 'minitest)

(defcustom minitest-default-env nil
  "Default env vars for minitest"
  :type 'string
  :group 'minitest)

(defun minitest-buffer-name (file-or-dir)
  (concat "*Minitest " file-or-dir "*"))

(defun minitest-test-command ()
  (if (minitest-zeus-p) "test" '("ruby" "-Ilib:test")))

(defun minitest-project-root ()
  "Retrieve the root directory of a project if available.
The current directory is assumed to be the project's root otherwise."
  (or (->> '("Rakefile" "Gemfile")
        (--map (locate-dominating-file default-directory it))
        (-remove #'null)
        (car))
      (error "You're not into a project")))

(defun minitest-zeus-p ()
  (and minitest-use-zeus-when-possible
       (file-exists-p (concat (minitest-project-root) ".zeus.sock"))))

(define-derived-mode minitest-compilation-mode compilation-mode ""
  (add-hook 'compilation-filter-hook 'colorize-compilation-buffer))

(defun colorize-compilation-buffer ()
  (toggle-read-only)
  (ansi-color-apply-on-region (point-min) (point-max))
  (toggle-read-only))

(defvar minitest--last-command nil
  "Variable to store the last command running.")

(defun minitest--run-command (command &optional file-name)
  (let ((default-directory (minitest-project-root))
        (compilation-scroll-output t)
        (actual-command (concat (or minitest-default-env "") " " command)))
    (setq minitest--last-command (list command file-name))
    (compilation-start
     actual-command
     'minitest-compilation-mode
     (lambda (arg) (minitest-buffer-name (or file-name ""))))))

(defun minitest--file-command (&optional post-command)
  "Run COMMAND on currently visited file."
  (let ((file-name (buffer-file-name (current-buffer)))
        (command (minitest-test-command))
        (zeus-command (if (minitest-zeus-p) '("bundle" "exec" "zeus") nil)))
    (if file-name
        (minitest--run-command
         (mapconcat 'shell-quote-argument
                    (-flatten
                     (--remove (eq nil it)
                               (list zeus-command command file-name post-command))) " ")
         file-name)
      (error "Buffer is not visiting a file"))))

(defun minitest--extract-str (str)
  (or (string-match "test \"\\([^\"]+?\\)\" do" str)
      (string-match "def test_\\([_A-Za-z0-9]+\\)" str)))

(defun minitest-verify ()
  "Run on current file."
  (interactive)
  (minitest--file-command))

(defun minitest-verify-single ()
  "Run on current file."
  (interactive)
  (let ((str (thing-at-point 'line)))
    (if (minitest--extract-str str)
        (minitest--file-command
         (format  "-ntest_%s" (replace-regexp-in-string " " "_" (match-string 1 str)))))))

(defun minitest-rerun ()
  "Run the last command"
  (interactive)
  (if minitest--last-command
      (apply #'minitest--run-command minitest--last-command)
    (error "There is no previous command to run")))

;;; Minor mode
(defvar minitest-mode-map
  (let ((map (make-sparse-keymap)))
    (let ((prefix-map (make-sparse-keymap)))
      (define-key prefix-map (kbd "v") 'minitest-verify)
      (define-key prefix-map (kbd "s") 'minitest-verify-single)
      (define-key prefix-map (kbd "r") 'minitest-rerun)
      (define-key map minitest-keymap-prefix prefix-map))
    map)
  "Keymap for minitest-mode.")

;;;###autoload
(define-minor-mode minitest-mode
  "Minor mode for *_test (minitest) files"
  :lighter " Minitest"
  :keymap minitest-mode-map
  :group 'minitest)

(provide 'minitest)

;;; minitest.el ends here
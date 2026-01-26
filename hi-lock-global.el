;;; hi-lock-global.el --- Apply hi-lock patterns globally across all buffers -*- lexical-binding: t -*-

;; Copyright (C) 2024  Naoya Yamashita

;; Author: Naoya Yamashita <conao3@gmail.com>
;; Version: 0.0.1
;; Keywords: convenience
;; Package-Requires: ((emacs "26.1"))
;; URL: https://github.com/conao3/hi-lock-global.el

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package extends hi-lock to apply highlighting patterns globally
;; across all buffers using advice.
;;
;; Usage:
;;   (require 'hi-lock-global)
;;   (hi-lock-global-mode 1)
;;
;; Then use the normal hi-lock commands (`highlight-regexp', etc.)
;; and they will be applied to all buffers automatically.


;;; Code:

(require 'hi-lock)

(defgroup hi-lock-global nil
  "Apply hi-lock patterns globally across all buffers."
  :group 'hi-lock)

(defcustom hi-lock-global-exclude-buffer-regexp
  '("\\` " "\\`\\*.*\\*\\'")
  "List of regexps matching buffer names to exclude."
  :type '(repeat regexp))

(defvar hi-lock-global-patterns nil
  "List of (REGEXP . ARGS) for global patterns.")

(defun hi-lock-global--buffer-excluded-p (&optional buffer)
  "Return non-nil if BUFFER should be excluded."
  (let ((buf (or buffer (current-buffer))))
    (with-current-buffer buf
      (or (memq major-mode hi-lock-exclude-modes)
          (cl-some (lambda (re) (string-match-p re (buffer-name)))
                   hi-lock-global-exclude-buffer-regexp)))))

(defun hi-lock-global--apply-to-buffer (&optional buffer)
  "Apply all global patterns to BUFFER."
  (let ((buf (or buffer (current-buffer))))
    (when (and (buffer-live-p buf)
               (not (hi-lock-global--buffer-excluded-p buf)))
      (with-current-buffer buf
        (dolist (pat hi-lock-global-patterns)
          (unless hi-lock-mode (hi-lock-mode 1))
          (apply #'hi-lock-set-pattern pat))))))

(defun hi-lock-global--after-set-pattern (regexp &rest args)
  "Advice after `hi-lock-set-pattern' to apply globally."
  (when hi-lock-global-mode
    (let ((pattern (cons regexp args)))
      (unless (member pattern hi-lock-global-patterns)
        (push pattern hi-lock-global-patterns)
        (dolist (buf (buffer-list))
          (unless (eq buf (current-buffer))
            (hi-lock-global--apply-to-buffer buf)))))))

(defun hi-lock-global--after-unface-buffer (regexp)
  "Advice after `hi-lock-unface-buffer' to remove globally."
  (when hi-lock-global-mode
    (if (eq regexp t)
        (let ((patterns hi-lock-global-patterns))
          (setq hi-lock-global-patterns nil)
          (dolist (buf (buffer-list))
            (unless (eq buf (current-buffer))
              (with-current-buffer buf
                (when hi-lock-mode
                  (hi-lock-unface-buffer t))))))
      (setq hi-lock-global-patterns
            (cl-remove-if (lambda (p) (equal (car p) regexp))
                          hi-lock-global-patterns))
      (dolist (buf (buffer-list))
        (unless (eq buf (current-buffer))
          (with-current-buffer buf
            (when hi-lock-mode
              (hi-lock-unface-buffer regexp))))))))

(defun hi-lock-global--new-buffer-hook ()
  "Apply global patterns to new buffer."
  (when hi-lock-global-mode
    (hi-lock-global--apply-to-buffer)))

;;;###autoload
(define-minor-mode hi-lock-global-mode
  "Toggle global hi-lock mode.
When enabled, hi-lock patterns are applied to all buffers."
  :global t
  :lighter " HiG"
  (if hi-lock-global-mode
      (progn
        (global-hi-lock-mode 1)
        (advice-add 'hi-lock-set-pattern :after #'hi-lock-global--after-set-pattern)
        (advice-add 'hi-lock-unface-buffer :after #'hi-lock-global--after-unface-buffer)
        (add-hook 'after-change-major-mode-hook #'hi-lock-global--new-buffer-hook))
    (advice-remove 'hi-lock-set-pattern #'hi-lock-global--after-set-pattern)
    (advice-remove 'hi-lock-unface-buffer #'hi-lock-global--after-unface-buffer)
    (remove-hook 'after-change-major-mode-hook #'hi-lock-global--new-buffer-hook)))

(provide 'hi-lock-global)

;;; hi-lock-global.el ends here

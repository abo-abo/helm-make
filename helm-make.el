;;; helm-make.el --- Select a Makefile target with helm

;; Copyright (C) 2014 Oleh Krehel

;; Author: Oleh Krehel <ohwoeowho@gmail.com>
;; URL: https://github.com/abo-abo/helm-make
;; Version: 0.2.0
;; Package-Requires: ((helm "1.5.3") (projectile "0.11.0"))
;; Keywords: makefile

;; This file is not part of GNU Emacs

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; A call to `helm-make' will give you a `helm' selection of this directory
;; Makefile's targets.  Selecting a target will call `compile' on it.

;;; Code:

(require 'helm)
(require 'helm-multi-match)

(declare-function ivy-read "ext:ivy")

(defgroup helm-make nil
  "Select a Makefile target with helm."
  :group 'convenience)

(defcustom helm-make-do-save nil
  "If t, save all open buffers visiting files from Makefile's directory."
  :type 'boolean
  :group 'helm-make)

(defcustom helm-make-build-dir ""
  "Specify a build directory for an out of source build.
The path should be relative to the project root.

When non-nil `helm-make-projectile' will first look in that directory for a
makefile."
  :type '(string)
  :group 'helm-make)
(make-variable-buffer-local 'helm-make-build-dir)

(defcustom helm-make-sort-targets nil
  "Whether targets shall be sorted.
If t, targets will be sorted as a final step, before calling the
completion method.

HINT: If you are facing performance problems set this to nil.
This might be the case, if there are thousand of targets."
  :type 'boolean
  :group 'helm-make)

(defcustom helm-make-cache-targets nil
  "Whether to cache the targets or not.

If t cache the targets of the Makefile. If `helm-make' or
`helm-make-projectile' gets called for the same Makefile again, and
the Makefile hasn't changed meanwhile, i.e. the modification time is
equal to the cached one, reuse the cached targets, instead of
recomputing them. If nil do nothing."
  :type 'boolean
  :group 'helm-make)

(defvar helm-make-command nil
  "Store the make command.")

(defvar helm-make-target-history nil
  "Holds the recently used targets.")

(defvar helm-make-makefile-modtime nil
  "A list of the form (makefile modtime).")

(defvar helm-make-make-targets nil
  "Holds the targets of the last used Makefile.")

(defvar helm-make-makefile-names '("Makefile" "makefile" "GNUmakefile")
  "List of Makefile names which make recognizes.
An exception is \"GNUmakefile\", only GNU make unterstand it.")

(defun helm-make-action (target)
  "Make TARGET."
  (compile (format helm-make-command target)))

(defcustom helm-make-completion-method 'helm
  "Method to select a candidate from a list of strings."
  :type '(choice
          (const :tag "Helm" helm)
          (const :tag "Ido" ido)
          (const :tag "Ivy" ivy)))

;;;###autoload
(defun helm-make (&optional arg)
  "Call \"make -j ARG target\". Target is selected with completion."
  (interactive "p")
  "make %s"
  (setq helm-make-command (format "make -j%d %%s" arg))
  (let ((makefile (helm--make-makefile-exists)))
    (if makefile
        (helm--make makefile)
      (error "No Makefile in %s" default-directory))))

(defun helm--make-target-list-qp (makefile)
  "Return sorted target list for MAKEFILE using \"make -nqp\"."
  (let ((default-directory (file-name-directory
                            (expand-file-name makefile)))
        targets target)
    (with-temp-buffer
      (insert
       (shell-command-to-string
        "make -nqp __BASH_MAKE_COMPLETION__=1 .DEFAULT 2>/dev/null"))
      (goto-char (point-min))
      (unless (re-search-forward "^# Files" nil t)
        (error "Unexpected \"make -nqp\" output"))
      (while (re-search-forward "^\\([^%$:#\n\t ]+\\):\\([^=]\\|$\\)" nil t)
        (setq target (match-string 1))
        (unless (or (save-excursion
		      (goto-char (match-beginning 0))
		      (forward-line -1)
		      (looking-at "^# Not a target:"))
		    (string-match "^\\." target))
          (push target targets)))
      (if helm-make-sort-targets
          (sort (delete-dups targets) 'string<)
        targets))))

(defun helm--make-target-list-default (makefile)
  "Return the target list for MAKEFILE by parsing it."
  (let (targets)
    (with-temp-buffer
      (insert-file-contents makefile)
      (goto-char (point-min))
      (while (re-search-forward "^\\([^: \n]+\\):" nil t)
        (let ((str (match-string 1)))
          (unless (string-match "^\\." str)
            (push str targets)))))
    (if helm-make-sort-targets
        (sort (delete-dups targets) 'string<)
      targets)))

(defcustom helm-make-list-target-method 'default
  "Method of obtaining the list of Makefile targets."
  :type '(choice
          (const :tag "Default" default)
          (const :tag "make -qp" qp)))

(defun helm--make-makefile-exists (&optional base-dir sub-dirs)
  "Check, if one of `helm-make-makefile-names' exist in `default-directory'.

Returns the absolute Makefile path, if a Makefile exists, otherwise nil.

If BASE-DIR is non-nil, use BASE-DIR as `default-directory'.
If SUB-DIRS is non-nil, also search for `helm-make-makefile-names' in that
directories. SUB-DIRS should be a list of directories relative to BASE-DIR
or `default-directory'."
  (let* ((default-directory (if (and base-dir (stringp base-dir))
                                base-dir
                              default-directory))
         (makefiles
          (if (and sub-dirs (listp sub-dirs))
              (let ((result))
                (dolist (dir sub-dirs)
                  (dolist (makefile helm-make-makefile-names)
                    (push (format "%s/%s" dir makefile) result)))
                (reverse result))
            helm-make-makefile-names))
         (makefile
          (cl-find-if 'file-exists-p
                      (mapcar
                       (lambda (x)
                         (expand-file-name x))
                       makefiles))))
    makefile))

(defun helm--make (makefile)
  "Call make for MAKEFILE."
  (when helm-make-do-save
    (let* ((regex (format "^%s" default-directory))
           (buffers
            (cl-remove-if-not
             (lambda (b)
               (let ((name (buffer-file-name b)))
                 (and name
                      (string-match regex (expand-file-name name)))))
             (buffer-list))))
      (mapc
       (lambda (b)
         (with-current-buffer b
           (save-buffer)))
       buffers)))
  (let* ((att (file-attributes makefile 'integer))
         (modtime (if att (nth 5 att) nil))
         (targets (cond
                   ((if (and helm-make-cache-targets
                             (equal modtime (cadr helm-make-makefile-modtime))
                             (equal makefile (car helm-make-makefile-modtime)))
                        helm-make-make-targets
                      (when helm-make-cache-targets
                        (setq helm-make-makefile-modtime `(,makefile ,modtime)))
                      nil))
                   ((eq helm-make-list-target-method 'default)
                    (helm--make-target-list-default makefile))
                   (t (helm--make-target-list-qp makefile))))
         (default-directory (file-name-directory makefile)))
    (when helm-make-cache-targets
      (setq helm-make-make-targets targets))
    (message "Before: %s" helm-make-target-history)
    (delete-dups helm-make-target-history)
    (cl-case helm-make-completion-method
      (helm
       (helm :sources
             `((name . "Targets")
               (candidates . ,targets)
               (action . helm-make-action))
             :history 'helm-make-target-history
             :preselect (when helm-make-target-history
                          (format "^%s$" (car helm-make-target-history)))))
      (ivy
       (ivy-read "Target: "
                 targets
                 :history 'helm-make-target-history
                 :preselect (car helm-make-target-history)
                 :action 'helm-make-action
                 :require-match t))
      (ido
       (let ((target (ido-completing-read
                      "Target: " targets
                      nil nil nil
                      'helm-make-target-history)))
         (when target
           (helm-make-action target)))))
    (message "After: %s" helm-make-target-history)))

;;;###autoload
(defun helm-make-projectile (&optional arg)
  "Call `helm-make' for `projectile-project-root'.
ARG specifies the number of cores.

By default `helm-make-projectile' will look in `projectile-project-root'
followed by `projectile-project-root'/build, for a makefile.

You can specify an additional directory to search for a makefile by
setting the buffer local variable `helm-make-build-dir'."
  (interactive "p")
  (require 'projectile)
  (setq helm-make-command (format "make -j%d %%s" arg))
  (let ((makefile (helm--make-makefile-exists
                   (projectile-project-root)
                   (if (and (stringp helm-make-build-dir)
                            (not (string-blank-p helm-make-build-dir)))
                       `(,helm-make-build-dir "" "build")
                     `(,@helm-make-build-dir "" "build")))))
    (if makefile
        (helm--make makefile)
      (error "No Makefile found for project %s" (projectile-project-root)))))

(provide 'helm-make)

;;; helm-make.el ends here

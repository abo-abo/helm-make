;;; helm-make.el --- Select makefile target with helm.

;; Copyright (C) 2014 Oleh Krehel

;; Author: Oleh Krehel <ohwoeowho@gmail.com>
;; URL: https://github.com/abo-abo/helm-make
;; Version: 0.1
;; Package-Requires: ((helm "1.5.3"))
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
;; A call to `hm' will give you a `helm' selection of this directory
;; Makefile's targets.  Selecting a target will call `compile' on it.

;;; Code:

(require 'helm)

(defun hm-action (target)
  "Make TARGET."
  (compile (format "make %s" target)))

;;;###autoload
(defun hm ()
  "Use `helm' to select a Makefile target and `compile'."
  (interactive)
  (let ((file (expand-file-name "Makefile"))
        targets)
    (if (file-exists-p file)
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (let (targets)
            (while (re-search-forward "^\\([^: \n]+\\):" nil t)
              (let ((str (match-string 1)))
                (unless (string-match "^\\." str)
                  (push str targets))))
            (helm :sources
                  `((name . "Targets")
                    (candidates . ,(nreverse targets))
                    (action . hm-action)))
            (message "%s" targets)))
      (error "No Makefile in %s" default-directory))))

(provide 'helm-make)

;;; helm-make.el ends here

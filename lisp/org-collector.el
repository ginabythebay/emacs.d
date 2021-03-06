;;; org-collector --- collect properties into tables

;; Copyright (C) 2008-2018 Free Software Foundation, Inc.

;; Author: Eric Schulte <schulte dot eric at gmail dot com>
;; Keywords: outlines, hypermedia, calendar, wp, experimentation,
;;           organization, properties
;; Homepage: https://orgmode.org
;; Version: 0.01

;; This file is not yet part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Pass in an alist of columns, each column can be either a single
;; property or a function which takes column names as arguments.
;;
;; For example the following propview block would collect the value of
;; the 'amount' property from each header in the current buffer
;;
;; #+BEGIN: propview :cols (ITEM amount)
;; | "ITEM"              | "amount" |
;; |---------------------+----------|
;; | "December Spending" |        0 |
;; | "Grocery Store"     |    56.77 |
;; | "Athletic club"     |     75.0 |
;; | "Restaurant"        |    30.67 |
;; | "January Spending"  |        0 |
;; | "Athletic club"     |     75.0 |
;; | "Restaurant"        |    50.00 |
;; |---------------------+----------|
;; |                     |          |
;; #+END:
;;
;; This slightly more selective propview block will limit those
;; headers included to those in the subtree with the id 'december'
;; in which the spendtype property is equal to "food"
;;
;; #+BEGIN: propview :id "december" :conds ((string= spendtype "food")) :cols (ITEM amount)
;; | "ITEM"          | "amount" |
;; |-----------------+----------|
;; | "Grocery Store" |    56.77 |
;; | "Restaurant"    |    30.67 |
;; |-----------------+----------|
;; |                 |          |
;; #+END:
;;
;; Org Collector allows arbitrary processing of the property values
;; through elisp in the cols: property.  This allows for both simple
;; computations as in the following example
;;
;; #+BEGIN: propview :id "results" :cols (ITEM f d list (apply '+ list) (+ f d))
;; | "ITEM" | "f" | "d" | "list"                  | "(apply (quote +) list)" | "(+ f d)" |
;; |--------+-----+-----+-------------------------+--------------------------+-----------|
;; | "run1" |   2 |  33 | (quote (9 2 3 4 5 6 7)) | 36                       |        35 |
;; | "run2" |   2 |  34 | :na                     | :na                      |        36 |
;; | "run3" |   2 |  35 | :na                     | :na                      |        37 |
;; | "run4" |   2 |  36 | :na                     | :na                      |        38 |
;; |        |     |     |                         |                          |           |
;; #+END:
;;
;; or more complex computations as in the following example taken from
;; an org file where each header in "results" subtree contained a
;; property "sorted_hits" which was passed through the
;; "average-precision" elisp function
;;
;; #+BEGIN: propview :id "results" :cols (ITEM (average-precision sorted_hits))
;; | "ITEM"    | "(average-precision sorted_hits)" |
;; |-----------+-----------------------------------|
;; | run (80)  |                          0.105092 |
;; | run (70)  |                          0.108142 |
;; | run (10)  |                          0.111348 |
;; | run (60)  |                          0.113593 |
;; | run (50)  |                          0.116446 |
;; | run (100) |                          0.118863 |
;; #+END:
;;

;;; Code:
(require 'org)
(require 'org-table)

(defvar org-propview-default-value 0
  "Default value to insert into the propview table when the no
value is calculated either through lack of required variables for
a column, or through the generation of an error.")

(defun and-rest (list)
  "Return nil unless all elements of LIST are non-nil."
  (if (listp list)
      (seq-reduce (lambda (a b) (and a b)) list t)
      list))

(put 'org-collector-error
     'error-conditions
     '(error column-prop-error org-collector-error))

(defun org-dblock-write:propview (params)
  "collect the column specification from the #+cols line
preceeding the dblock, then update the contents of the dblock."
  (interactive)
  (save-restriction
      (let ((cols (plist-get params :cols))
	    (inherit (plist-get params :inherit))
	    (conds (plist-get params :conds))
	    (match (plist-get params :match))
	    (scope (plist-get params :scope))
	    (noquote (plist-get params :noquote))
	    (colnames (plist-get params :colnames))
	    (defaultval (plist-get params :defaultval))
	    (content-lines (org-split-string (plist-get params :content) "\n"))
            (sort (plist-get params :sort))
	    id table line pos)
	(save-excursion
	  (when (setq id (plist-get params :id))
	    (cond ((not id) nil)
		  ((eq id 'global) (goto-char (point-min)))
		  ((eq id 'local)  nil)
		  ((setq idpos (org-find-entry-with-id id))
		   (goto-char idpos))
		  (t (error "Cannot find entry with :ID: %s" id))))
	  (unless (eq id 'global) (org-narrow-to-subtree))
	  (setq stringformat (if noquote "%s" "%S"))
	  (let ((org-propview-default-value (if defaultval defaultval org-propview-default-value)))
	    (setq table (org-propview-to-table
			 (org-propview-collect cols stringformat conds match scope inherit
					       (if colnames colnames cols)) stringformat)))
	  (widen))
	(setq pos (point))
        (while (and content-lines (string-match "^#" (car content-lines)))
          (insert (pop content-lines) "\n"))
	(insert table) (insert "\n|--") (org-cycle) (move-end-of-line 1)
	(message (format "point-%d" pos))
	(while (setq line (pop content-lines))
	  (when (string-match "^#" line)
	    (insert "\n" line)))
	(goto-char pos)
	(org-table-recalculate 'all)
        (when sort
          (unless (= 3 (length sort))
            (user-error "Could not parse :sort parameter %S.  Should be in the format (<col-no> <with-case> <sorting-type>)" sort)
            )
          (org-table-goto-line 2)
          (org-table-goto-column (nth 0 sort))
          (org-table-sort-lines (nth 1 sort) (nth 2 sort))))))

(defun org-propview-eval-w-props (props body)
  "evaluate the BODY-FORMS binding the variables using the
variables and values specified in props"
  (condition-case nil ;; catch any errors
      (eval `(let ,(mapcar
		    (lambda (pair) (list (intern (car pair)) (cdr pair)))
		    props)
	       ,body))
    (error nil)))

(defun org-propview-get-with-inherited (&optional inherit)
  (append
   (org-entry-properties)
   (delq nil
	 (mapcar (lambda (i)
		   (let* ((n (symbol-name i))
			  (p (org-entry-get (point) n 'do-inherit)))
		     (when p (cons n p))))
		 inherit))))

(defun org-propview-get-contents ()
  "Return the content of the current entry.
This is the text of the entry, minus any properties etcetera and
minus any headings below it."
  (save-excursion
    (save-match-data
      (org-back-to-heading t)
      (org-end-of-meta-data t)
      (let ((start (point)))
        (re-search-forward "^\\*+ " nil 'move)
        (beginning-of-line)
        (when (memq (preceding-char) '(?\n ?\^M))
	  ;; Go to end of line before heading
	  (forward-char -1)
	  (when (memq (preceding-char) '(?\n ?\^M))
	    ;; leave blank line before heading
	    (forward-char -1)))
        (replace-regexp-in-string
         "\n" " "
         (replace-regexp-in-string
          "\n\n" "@@html:<br>@@@@html:<br>@@"
          (string-trim
           (buffer-substring-no-properties start (point)))))))))

(defun org-propview-collect (cols stringformat &optional conds match scope inherit colnames)
  (interactive)
  ;; collect the properties from every header
  (let* ((header-props
	  (let ((org-trust-scanner-tags t) alst)
	    (org-map-entries
             (quote
              ;; If we decide org-propview-get-contents slows things
              ;; down in the general case, we could only call it when
              ;; we see it is used in 'cols'
              (cons (cons "ENTRY" (org-propview-get-contents))
                    (org-propview-get-with-inherited inherit)))
	     match scope)))
	 ;; read property values
	 (header-props
	  (mapcar (lambda (props)
		    (mapcar (lambda (pair)
			      (cons (car pair) (substring-no-properties (cdr pair))))
			    props))
		  header-props))
	 ;; collect all property names
	 (prop-names
	  (mapcar 'intern (delete-dups
			   (apply 'append (mapcar (lambda (header)
						    (mapcar 'car header))
						  header-props))))))
    (append
     (list
      (if colnames colnames (mapcar (lambda (el) (format stringformat el)) cols))
       'hline) ;; ------------------------------------------------
     (mapcar ;; calculate the value of the column for each header
      (lambda (props) (mapcar (lambda (col)
			        (let ((result (org-propview-eval-w-props props col)))
			          (if result result org-propview-default-value)))
			      cols))
      (if conds
	  ;; eliminate the headers which don't satisfy the property
	  (delq nil
		(mapcar
		 (lambda (props)
		   (if (and-rest (mapcar
				  (lambda (col)
				    (org-propview-eval-w-props props col))
				  conds))
		       props))
		 header-props))
	header-props)))))

(defun org-propview-to-table (results stringformat)
  ;; (message (format "cols:%S" cols))
  (orgtbl-to-orgtbl
   (mapcar
    (lambda (row)
      (if (equal row 'hline)
	  'hline
	(mapcar (lambda (el) (format stringformat el)) row)))
    (delq nil results)) '(:raw t)))

(provide 'org-collector)
;;; org-collector ends here

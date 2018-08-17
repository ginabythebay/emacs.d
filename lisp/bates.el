;;; bates.el --- helps with bates numbers                     -*- lexical-binding: t; -*-

;; Copyright (C) 2018  Gina White

;; Author: Gina White <ginabythebay@gmail.com>
;; Keywords: lisp
;; Version: 0.0.1

;;; Commentary:

;; not much to say here

;;; Code:

;; code goes here

(require 'cl-macs)
(require 'seq)

(defvar bates--ring '()
  "Stores the last few (up to two) bates numbers marked.")

(defvar bates--max-bates-no '()
  "Stores the last valid bates number of a file when we marked a bates page.")

(cl-defstruct (bates-page (:constructor create--bates-page)
              (:copier nil))
  prefix        ; e.g. "COB"
  no            ; the numeric portion of the bates number
  (width nil))  ; if set, the length fill to when printing

(defun create-bates-page (prefix no width)
  "Create a bates number with no filling.
PREFIX is something like \"COB\".
NO is a bates number.
WIDTH is the minimum printed width of the bates number, if set."
  (create--bates-page :prefix prefix :no no :width width))

(defun bates--decode-bates-range (name)
  "Decodes a NAME like 'COB0002421-COB0003964' into ('COB' 2421 3964)."
  (unless (string-match "\\([A-Z]+\\)\\([0-9]+\\)[^A-Z]*\\([A-Z]+\\)\\([0-9]+\\)" name)
    (user-error "Unable to decode `%s': Expected something like COB0002421-COB0003964" name))
  (let* ((prefix1 (match-string 1 name))
        (start (match-string 2 name))
        (prefix2 (match-string 3 name))
        (end (match-string 4 name))
        (width nil))
    (unless (string= prefix1 prefix2)
      (user-error "Invalid name `%s', `%s'!=`%s'.  Expected something like COB0002421-COB0003964" name prefix1 prefix2))
    (when (equal ?0 (aref start 0))
        (unless (equal
                 (string-width start)
                 (string-width end))
          (user-error "Invalid digits in `%s'.  When leading zeros are found, the numeric portions must have the same length" name))
        (setq width (string-width start)))
    (list (create-bates-page prefix1 (string-to-number start) width)
     (create-bates-page prefix1 (string-to-number end ) width))))

(ert-deftest bates--decode-bates-range ()
  "Tests bates file base name decoding"
  (should (equal
           (bates--decode-bates-range "COB0002421-COB0003964")
           (list (create-bates-page "COB" 2421 7)
            (create-bates-page "COB" 3964 7))))
  (should (equal
           (bates--decode-bates-range "COB0002421 - COB0003964")
           (list (create-bates-page "COB" 2421 7)
            (create-bates-page "COB" 3964 7))))
  (should (equal
           (bates--decode-bates-range "COB2421-COB3964")
           (list (create-bates-page "COB" 2421 nil)
            (create-bates-page "COB" 3964 nil)))))


(defun bates--format (val &optional short)
  "Format VAL for printing.
Optional parameter SHORT means to use short form."
  (let ((fmt (if (and (not short) (bates-page-width val))
                 (format "%%s%%0%dd" (bates-page-width val))
               "%s %d")))
    (format fmt (bates-page-prefix val) (bates-page-no val))))

(ert-deftest bates--format ()
  "Tests bates formatting"
  (should (equal
           (bates--format (create-bates-page "COB" 2421 7))
           "COB0002421"))
  (should (equal
           (bates--format (create-bates-page "COB" 2421 7) t)
           "COB 2421"))
  (should (equal
           (bates--format (create-bates-page "COB" 2421 nil))
           "COB 2421"))
  (should (equal
           (bates--format (create-bates-page "COB" 2421 nil) t)
           "COB 2421")))

(defun bates--expected-pdf-pages (file-range)
  "Return the expected number of pdf pages in FILE-RANGE."
  (+ 1 (- (bates-page-no (nth 1 file-range)) (bates-page-no (nth 0 file-range)))))


(ert-deftest bates--expected-pdf-pages ()
  "Tests bates pdf page expectations."
  (should (equal
           1
           (bates--expected-pdf-pages
            (list (create-bates-page "COB" 2421 7)
                  (create-bates-page "COB" 2421 7)))))
  (should (equal
           4
           (bates--expected-pdf-pages
            (list (create-bates-page "COB" 2421 nil)
                  (create-bates-page "COB" 2424 nil))))))

(defun bates--ring-new (e)
  "Add E to bates--ring, ensuring only 2 items at most are retained."
  (setq bates--ring (append  bates--ring (list e)))
  (when (> (length bates--ring) 2)
    (setq bates--ring (seq-subseq bates--ring -2))))

(ert-deftest bates--ring-new ()
  "Tests bates ring adding."
  (setq bates--ring (list))

  (bates--ring-new (create-bates-page "COB" 2423 nil))
  (should (equal 1 (length bates--ring)))
  (should (equal 2423 (bates-page-no (car (last bates--ring)))))

  (bates--ring-new (create-bates-page "COB" 2424 nil))
  (should (equal 2 (length bates--ring)))
  (should (equal 2424 (bates-page-no (car (last bates--ring)))))

  (bates--ring-new (create-bates-page "COB" 2425 nil))
  (should (equal 2 (length bates--ring)))
  (should (equal 2425 (bates-page-no (car (last bates--ring))))))

(defun bates--copy ()
  "Copy the current bates entry to the bates--ring."
  (let* ((file-range (bates--decode-bates-range(file-name-base (buffer-file-name))))
         (start (nth 0 file-range))
         (end (nth 1 file-range))
         (expected-pdf-pages (bates--expected-pdf-pages file-range)))
    (unless (equal expected-pdf-pages (pdf-cache-number-of-pages))
      (user-error "Based on a start of `%s' and an end of %d, we expected %d pages but found %d"
                  start end expected-pdf-pages (pdf-cache-number-of-pages)))

    (cl-incf (bates-page-no start) (- (pdf-view-current-page) 1))
    (bates--ring-new start)
    (setq bates--max-bates-no (bates-page-no end))

    (message "stored %s" (bates--format start))))

(defun bates--ordered-ring ()
  "Return the contents of the bates--ring in order."
  (let ((a (nth 0 bates--ring))
        (b (nth 1 bates--ring)))
    (unless (equal (bates-page-prefix a) (bates-page-prefix b))
      (user-error "It doesn't make sense to combine the prefixes `%s' and `%s'"
                  (bates-page-prefix a) (bates-page-prefix b)))

    ; no matter what order they were marked, put the small number first
    (if (< (bates-page-no a) (bates-page-no b))
        (list a b)
      (list b a))))

(defun bates--paste-text ()
  "Get the text to paste based on the bates--ring."
  (unless (> (length bates--ring) 1)
    (user-error "Not enough entries.  Run this command in pdf-view-mode at least twice first"))

  (let* ((ring (bates--ordered-ring))
         (a (nth 0 ring))
         (b (nth 1 ring)))
    (let ((atext (bates--format a t))
          (btext (bates--format b t)))
      (if (equal atext btext)
          atext
        (format "%s - %s" atext btext)))))


(ert-deftest bates--paste-text ()
  "Tests bates pdf page expectations."
  (setq bates--ring (list
                     (create-bates-page "COB" 2421 7)
                     (create-bates-page "COB" 2421 7)))
  (should (equal "COB 2421" (bates--paste-text)))
  (setq bates--ring (list
                     (create-bates-page "COB" 2421 6)
                     (create-bates-page "COB" 2423 6)))
  (should (equal "COB 2421 - COB 2423" (bates--paste-text)))
  (setq bates--ring (list
                     (create-bates-page "COB" 2423 nil)
                     (create-bates-page "COB" 2421 nil)))
  (should (equal "COB 2421 - COB 2423" (bates--paste-text))))


(defun bates--ring-maybe-next ()
  "Put the next page in the ring if won't exceed the last entry."
  (let* ((biggest (car (last (bates--ordered-ring))))
         (new (create-bates-page
                (bates-page-prefix biggest)
                (+ 1 (bates-page-no biggest))
                (bates-page-width biggest))))
    (when (<= (bates-page-no new) bates--max-bates-no)
      (bates--ring-new new)
      (bates--ring-new new))))

(ert-deftest bates--ring-maybe-next ()
  "Tests bates pdf page expectations."
  (setq bates--ring '())
  (bates--ring-new (create-bates-page "COB" 2423 nil))
  (bates--ring-new (create-bates-page "COB" 2421 nil))

  (setq bates--max-bates-no 3000)
  (bates--ring-maybe-next)
  (should (equal 2424 (bates-page-no (car (last bates--ring))))))


(defun bates--paste ()
  "Pastes the last two entries into the current buffer."
  (unless (> (length bates--ring) 1)
    (user-error "Not enough entries.  Run this command in pdf-view-mode at least twice first"))
  (kill-new (bates--paste-text))
  (yank)
  (bates--ring-maybe-next))

(defun bates-copy-or-paste ()
  "Copies the current bates number for the pdf in the current buffer to the kill ring."
  (interactive)
  (if (equal major-mode 'pdf-view-mode)
      (bates--copy)
    (bates--paste)))

(global-set-key "\C-b" 'bates-copy-or-paste)


(defun bates-create-skeleton ()
  "Create notes skeleton with the PDF outline or annotations.
Only available with PDF Tools."
  (interactive)
  (org-noter--with-valid-session
   (cond
    ((eq (org-noter--session-doc-mode session) 'pdf-view-mode)
     (let* ((ast (org-noter--parse-root))
            (top-level (org-element-property :level ast))
            (options '(("Outline" . (outline))
                       ("Annotations" . (annots))
                       ("Both" . (outline annots))))
            answer output-data file-range start end expected-pdf-pages )
       (with-current-buffer (org-noter--session-doc-buffer session)
         (setq file-range (bates--decode-bates-range(file-name-base (buffer-file-name))))
         (setq start (nth 0 file-range))
         (setq end (nth 1 file-range))
         (setq expected-pdf-pages (bates--expected-pdf-pages file-range))

         (unless (equal expected-pdf-pages (pdf-cache-number-of-pages))
           (user-error "Based on a start of `%s' and an end of %d, we expected %d pages but found %d"
                       start end expected-pdf-pages (pdf-cache-number-of-pages)))

         (setq answer (assoc (completing-read "What do you want to import? " options nil t) options))

         (when (memq 'outline answer)
           (dolist (item (pdf-info-outline))
             (let ((type  (alist-get 'type item))
                   (page  (alist-get 'page item))
                   (depth (alist-get 'depth item))
                   (title (alist-get 'title item))
                   (top   (alist-get 'top item)))
               (when (and (eq type 'goto-dest) (> page 0))
                 (push (vector title (cons page top) (1+ depth) nil) output-data)))))

         (when (memq 'annots answer)
           (let ((possible-annots (list '("Highlights" . highlight)
                                        '("Underlines" . underline)
                                        '("Squigglies" . squiggly)
                                        '("Text notes" . text)
                                        '("Strikeouts" . strike-out)
                                        '("Links" . link)
                                        '("ALL" . all)))
                 chosen-annots insert-contents pages-with-links)
             (while (> (length possible-annots) 1)
               (let* ((chosen-string (completing-read "Which types of annotations do you want? "
                                                      possible-annots nil t))
                      (chosen-pair (assoc chosen-string possible-annots)))
                 (cond ((eq (cdr chosen-pair) 'all)
                        (dolist (annot possible-annots)
                          (when (and (cdr annot) (not (eq (cdr annot) 'all)))
                            (push (cdr annot) chosen-annots)))
                        (setq possible-annots nil))
                       ((cdr chosen-pair)
                        (push (cdr chosen-pair) chosen-annots)
                        (setq possible-annots (delq chosen-pair possible-annots))
                        (when (= 1 (length chosen-annots)) (push '("DONE") possible-annots)))
                       (t
                        (setq possible-annots nil)))))

             (setq insert-contents (y-or-n-p "Should we insert the annotations contents? "))

             (dolist (item (pdf-info-getannots))
               (let* ((type  (alist-get 'type item))
                      (page  (alist-get 'page item))
                      (edges (or (org-noter--pdf-tools-edges-to-region (alist-get 'markup-edges item))
                                 (alist-get 'edges item)))
                      (top (nth 1 edges))
                      (item-subject (alist-get 'subject item))
                      (item-contents (alist-get 'contents item))
                      name contents)
                 (when (and (memq type chosen-annots) (> page 0))
                   (if (eq type 'link)
                       (cl-pushnew page pages-with-links)
                     (setq name (cond ((eq type 'highlight)  "Highlight")
                                      ((eq type 'underline)  "Underline")
                                      ((eq type 'squiggly)   "Squiggly")
                                      ((eq type 'text)       "Text note")
                                      ((eq type 'strike-out) "Strikeout")))

                     (when insert-contents
                       (setq contents (cons (pdf-info-gettext page edges)
                                            (and (or (and item-subject (> (length item-subject) 0))
                                                     (and item-contents (> (length item-contents) 0)))
                                                 (concat (or item-subject "")
                                                         (if (and item-subject item-contents) "\n" "")
                                                         (or item-contents ""))))))

                     (push (vector (format "%s on page %d" name page) (cons page top) 'inside contents)
                           output-data)))))

             (dolist (page pages-with-links)
               (let ((links (pdf-info-pagelinks page))
                     type)
                 (dolist (link links)
                   (setq type (alist-get 'type  link))
                   (unless (eq type 'goto-dest) ;; NOTE(nox): Ignore internal links
                     (let* ((edges (alist-get 'edges link))
                            (title (alist-get 'title link))
                            (top (nth 1 edges))
                            (target-page (alist-get 'page link))
                            target heading-text)

                       (unless (and title (> (length title) 0)) (setq title (pdf-info-gettext page edges)))

                       (cond
                        ((eq type 'uri)
                         (setq target (alist-get 'uri link)
                               heading-text (format "Link on page %d: [[%s][%s]]" page target title)))

                        ((eq type 'goto-remote)
                         (setq target (concat "file:" (alist-get 'filename link))
                               heading-text (format "Link to document on page %d: [[%s][%s]]" page target title))
                         (when target-page
                           (setq heading-text (concat heading-text (format " (target page: %d)" target-page)))))

                        (t (error "Unexpected link type")))

                       (push (vector heading-text (cons page top) 'inside nil) output-data))))))))

         (when output-data
           (setq output-data
                 (sort output-data
                       (lambda (e1 e2)
                         (or (not (aref e1 1))
                             (and (aref e2 1)
                                  (org-noter--compare-location-cons '< (aref e1 1) (aref e2 1)))))))
           (push (vector "Skeleton" nil 1 nil) output-data)))

       (with-current-buffer (org-noter--session-notes-buffer session)
         ;; NOTE(nox): org-with-wide-buffer can't be used because we want to reset the
         ;; narrow region to include the new headings
         (widen)
         (save-excursion
           (goto-char (org-element-property :end ast))

           (let (last-absolute-level
                 title location relative-level contents
                 level)
             (dolist (data output-data)
               (setq title          (aref data 0)
                     location       (aref data 1)
                     relative-level (aref data 2)
                     contents       (aref data 3))

               (if (symbolp relative-level)
                   (setq level (1+ last-absolute-level))
                 (setq last-absolute-level (+ top-level relative-level)
                       level last-absolute-level))

               (org-noter--insert-heading level title)

               (when location
                 (org-entry-put nil org-noter-property-note-location (org-noter--pretty-print-location location))
                 (when (or (not (cdr location)) (<= (cdr location) 0))
                   (let* ((page (car location))
                          (bts (create-bates-page (bates-page-prefix start) (- (+ page (bates-page-no start)) 1) nil)))
                     (org-entry-put nil "BATES" (bates--format bts)))))

               (when (car contents)
                 (org-noter--insert-heading (1+ level) "Contents")
                 (insert (car contents)))
               (when (cdr contents)
                 (org-noter--insert-heading (1+ level) "Comment")
                 (insert (cdr contents)))))

           (setq ast (org-noter--parse-root))
           (org-noter--narrow-to-root ast)
           (goto-char (org-element-property :begin ast))
           (outline-hide-subtree)
           (org-show-children 2)))))

    (t (error "This command is only supported on PDF Tools")))))


(provide 'bates)
;;; bates.el ends here

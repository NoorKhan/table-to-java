(ql:quickload 'qmynd)
(ql:quickload :modest-config)

(defparameter *connection*
  (modest-config:with-config "connection.config" (hostname username password database)
    (qmynd:mysql-connect :host hostname :username username :password password :database database)))

(defun execute-query (query)
  (qmynd:mysql-query
   *connection*
   query
   :result-type 'list))

(defparameter *sql-to-java-types-map* (make-hash-table :test 'equal))
(setf (gethash "int" *sql-to-java-types-map*) "int")
(setf (gethash "varchar" *sql-to-java-types-map*) "String")
(setf (gethash "longtext" *sql-to-java-types-map*) "String")
(setf (gethash "datetime" *sql-to-java-types-map*) "ZonedDateTime")
(setf (gethash "bit(1)" *sql-to-java-types-map*) "boolean")
(setf (gethash "bigint" *sql-to-java-types-map*) "long")
(setf (gethash "float" *sql-to-java-types-map*) "float")

(defun generate-class-from-database-table (table-name)
  (generate-class (underscore-to-snake-case (string-capitalize table-name)) (get-column-descriptions (get-table-description table-name))))

(defun get-table-description (table-name)
  (execute-query (concatenate 'string "DESCRIBE " table-name)))

(defun get-column-descriptions (table-description)
  (mapcar #'(lambda (column-description) (cons (first column-description) (get-column-type column-description))) table-description))

(defun get-column-type (column-description)
  (let ((database-type (second column-description))
	(nullable? (string-equal (third column-description) "yes")))
    (cond
      ((or (search "varchar" database-type) (search "longtext" database-type)) (gethash "varchar" *sql-to-java-types-map*))
      ((search "int" database-type) (if nullable? "Integer" (gethash "int" *sql-to-java-types-map*)))
      ((search "bigint" database-type) (if nullable? "Long" (gethash "bigint" *sql-to-java-types-map*)))
      ((search "float" database-type) (if nullable? "Float" (gethash "float" *sql-to-java-types-map*)))
      ((string-equal database-type "bit(1)") (if nullable? "Boolean" (gethash "bit(1)" *sql-to-java-types-map*)))
      ((string-equal database-type "datetime") (gethash "datetime" *sql-to-java-types-map*))
      (t "String"))))

(defun generate-class (class-name fields)
  (let ((class (concatenate 'string
			    (format nil "public class ~a {~2%" class-name)
			    (format nil "~{~a~}~%" (mapcar #'(lambda (field) (get-field field)) fields))
			    (get-constructor class-name fields)
			    (format nil "~{~a~^~%~}" (mapcar #'(lambda (field) (get-getter field)) fields))
			    (format nil "}~2%"))))
    (if (search "ZonedDateTime" class)
	(concatenate 'string (format nil "import java.time.ZonedDateTime;~2%") class)
	class)))

(defun get-field (field)
  (let ((field-name (underscore-to-snake-case (car field)))
	(field-type (cdr field)))
    (format nil "    private ~a ~a;~%" field-type field-name )))

(defun get-constructor (class-name fields)
  (let ((field-names-with-types (mapcar
				 #'(lambda (field) (concatenate 'string (cdr field) " " (underscore-to-snake-case (car field))))
				 fields))
	(field-setters (mapcar #'(lambda (field) (let ((field-name (underscore-to-snake-case (car field))))
						   (format nil "this.~a = ~a;" field-name field-name)))
			       fields)))
    (concatenate 'string
		 (format nil "    public ~a(~{~a~^,~^ ~}) {~%" class-name field-names-with-types)
		 (format nil "~{        ~a~%~}    }~2%" field-setters))))

(defun get-getter (field)
  (let ((snake-case-field-name (underscore-to-snake-case (car field)))
	(field-type (cdr field)))
    (format nil "    public ~a get~a() {~%        return this.~a;~%    }~%"
		  field-type
		  (concatenate 'string (string-capitalize (subseq snake-case-field-name 0 1)) (subseq snake-case-field-name 1))
		  snake-case-field-name)))

(defun underscore-to-snake-case (s)
  (if (search "_" s)
      (let ((split (split-sequence:split-sequence #\_ s)))
	(concatenate 'string (car split) (apply #'concatenate 'string (mapcar #'string-capitalize (cdr split)))))
      s))

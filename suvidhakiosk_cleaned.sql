

BEGIN
    FOR t IN (SELECT table_name FROM user_tables ORDER BY table_name DESC) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;
    FOR s IN (SELECT sequence_name FROM user_sequences) LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
    END LOOP;
END;
/

CREATE SEQUENCE seq_citizen       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_dept          START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_utility       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_request       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_complaint     START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_document      START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_receipt       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_audit         START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_district      START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_metric        START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE TABLE Districts (
    district_id     NUMBER          DEFAULT seq_district.NEXTVAL,
    district_name   VARCHAR2(60)    NOT NULL,
    state           VARCHAR2(40)    DEFAULT 'Punjab' NOT NULL,
    CONSTRAINT pk_districts         PRIMARY KEY (district_id),
    CONSTRAINT uq_district_name     UNIQUE (district_name),
    CONSTRAINT chk_district_state   CHECK (state IN ('Punjab', 'Haryana', 'HP', 'Other'))
);

CREATE TABLE Citizens (
    citizen_id      NUMBER          DEFAULT seq_citizen.NEXTVAL,
    first_name      VARCHAR2(50)    NOT NULL,
    last_name       VARCHAR2(50)    NOT NULL,
    aadhaar_no      CHAR(12)        NOT NULL,
    phone           VARCHAR2(15)    NOT NULL,
    email           VARCHAR2(100),
    address         VARCHAR2(255)   NOT NULL,
    district_id     NUMBER          NOT NULL,
    language_pref   VARCHAR2(20)    DEFAULT 'Hindi',
    created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_citizens          PRIMARY KEY (citizen_id),
    CONSTRAINT uq_citizen_aadhaar   UNIQUE (aadhaar_no),
    CONSTRAINT uq_citizen_phone     UNIQUE (phone),
    CONSTRAINT chk_aadhaar_format   CHECK (REGEXP_LIKE(aadhaar_no, '^[0-9]{12}$')),
    CONSTRAINT chk_phone_format     CHECK (REGEXP_LIKE(phone, '^[6-9][0-9]{9}$')),
    CONSTRAINT chk_language         CHECK (language_pref IN ('Hindi', 'Punjabi', 'English')),
    CONSTRAINT fk_citizen_district  FOREIGN KEY (district_id) REFERENCES Districts(district_id)
);

CREATE TABLE Departments (
    dept_id         NUMBER          DEFAULT seq_dept.NEXTVAL,
    dept_name       VARCHAR2(60)    NOT NULL,
    head_name       VARCHAR2(100),
    contact_phone   VARCHAR2(15),
    contact_email   VARCHAR2(100),
    CONSTRAINT pk_departments       PRIMARY KEY (dept_id),
    CONSTRAINT uq_dept_name         UNIQUE (dept_name),
    CONSTRAINT chk_dept_name        CHECK (dept_name IN (
                                        'Electricity', 'Gas', 'Water Supply',
                                        'Waste Management', 'General'))
);

CREATE TABLE Utilities (
    utility_id      NUMBER          DEFAULT seq_utility.NEXTVAL,
    utility_type    VARCHAR2(80)    NOT NULL,
    description     VARCHAR2(255),
    dept_id         NUMBER          NOT NULL,
    sla_days        NUMBER(3)       DEFAULT 7,
    CONSTRAINT pk_utilities         PRIMARY KEY (utility_id),
    CONSTRAINT uq_utility_type      UNIQUE (utility_type, dept_id),
    CONSTRAINT chk_sla              CHECK (sla_days BETWEEN 1 AND 90),
    CONSTRAINT fk_utility_dept      FOREIGN KEY (dept_id)
                                    REFERENCES Departments(dept_id)
                                    ON DELETE CASCADE
);

CREATE TABLE Service_Requests (
    req_id          NUMBER          DEFAULT seq_request.NEXTVAL,
    citizen_id      NUMBER          NOT NULL,
    utility_id      NUMBER          NOT NULL,
    category        VARCHAR2(60)    NOT NULL,
    description     VARCHAR2(1000),
    status          VARCHAR2(20)    DEFAULT 'Pending' NOT NULL,
    priority        VARCHAR2(10)    DEFAULT 'Normal',
    created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    resolved_at     TIMESTAMP,
    CONSTRAINT pk_service_requests  PRIMARY KEY (req_id),
    CONSTRAINT chk_req_status       CHECK (status IN (
                                        'Pending', 'In Progress', 'Resolved',
                                        'Rejected', 'Escalated')),
    CONSTRAINT chk_req_priority     CHECK (priority IN ('Low', 'Normal', 'High', 'Critical')),
    CONSTRAINT chk_resolved_after   CHECK (resolved_at IS NULL OR resolved_at >= created_at),
    CONSTRAINT fk_req_citizen       FOREIGN KEY (citizen_id)
                                    REFERENCES Citizens(citizen_id),
    CONSTRAINT fk_req_utility       FOREIGN KEY (utility_id)
                                    REFERENCES Utilities(utility_id)
);

CREATE TABLE Complaints (
    complaint_id    NUMBER          DEFAULT seq_complaint.NEXTVAL,
    citizen_id      NUMBER          NOT NULL,
    dept_id         NUMBER          NOT NULL,
    description     VARCHAR2(1000)  NOT NULL,
    status          VARCHAR2(20)    DEFAULT 'Open' NOT NULL,
    priority        VARCHAR2(10)    DEFAULT 'Normal',
    created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    resolved_at     TIMESTAMP,
    CONSTRAINT pk_complaints        PRIMARY KEY (complaint_id),
    CONSTRAINT chk_cmp_status       CHECK (status IN (
                                        'Open', 'Under Review', 'Resolved',
                                        'Rejected', 'Escalated')),
    CONSTRAINT chk_cmp_priority     CHECK (priority IN ('Low', 'Normal', 'High', 'Critical')),
    CONSTRAINT fk_cmp_citizen       FOREIGN KEY (citizen_id)
                                    REFERENCES Citizens(citizen_id)
                                    ON DELETE RESTRICT,
    CONSTRAINT fk_cmp_dept          FOREIGN KEY (dept_id)
                                    REFERENCES Departments(dept_id)
);

CREATE TABLE Documents (
    doc_id          NUMBER          DEFAULT seq_document.NEXTVAL,
    ref_type        CHAR(3)         NOT NULL,
    ref_id          NUMBER          NOT NULL,
    file_name       VARCHAR2(255)   NOT NULL,
    file_size_kb    NUMBER(10),
    mime_type       VARCHAR2(60),
    uploaded_at     TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_documents         PRIMARY KEY (doc_id),
    CONSTRAINT chk_doc_ref_type     CHECK (ref_type IN ('REQ', 'CMP')),
    CONSTRAINT chk_file_size        CHECK (file_size_kb > 0)
);

CREATE TABLE Receipts (
    receipt_id      NUMBER          DEFAULT seq_receipt.NEXTVAL,
    ref_type        CHAR(3)         NOT NULL,
    ref_id          NUMBER          NOT NULL,
    citizen_id      NUMBER          NOT NULL,
    generated_at    TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    details         VARCHAR2(500),
    CONSTRAINT pk_receipts          PRIMARY KEY (receipt_id),
    CONSTRAINT uq_receipt_ref       UNIQUE (ref_type, ref_id),
    CONSTRAINT chk_receipt_ref_type CHECK (ref_type IN ('REQ', 'CMP')),
    CONSTRAINT fk_receipt_citizen   FOREIGN KEY (citizen_id)
                                    REFERENCES Citizens(citizen_id)
                                    ON DELETE SET RESTRICT
);

CREATE TABLE Audit_Log (
    log_id          NUMBER          DEFAULT seq_audit.NEXTVAL,
    entity_type     VARCHAR2(20)    NOT NULL,
    entity_id       NUMBER          NOT NULL,
    old_status      VARCHAR2(20),
    new_status      VARCHAR2(20)    NOT NULL,
    changed_by      VARCHAR2(60)    DEFAULT 'SYSTEM',
    changed_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    remarks         VARCHAR2(255),
    CONSTRAINT pk_audit_log         PRIMARY KEY (log_id),
    CONSTRAINT chk_audit_entity     CHECK (entity_type IN ('REQUEST', 'COMPLAINT'))
);

CREATE TABLE Utility_Metrics (
    metric_id       NUMBER          DEFAULT seq_metric.NEXTVAL,
    district_id     NUMBER          NOT NULL,
    utility_type    VARCHAR2(80)    NOT NULL,
    metric_year     NUMBER(4)       NOT NULL,
    metric_value    NUMBER(15,2)    NOT NULL,
    unit            VARCHAR2(30),
    source          VARCHAR2(100)   DEFAULT 'Govt of Punjab Open Data',
    CONSTRAINT pk_utility_metrics   PRIMARY KEY (metric_id),
    CONSTRAINT uq_metric_key        UNIQUE (district_id, utility_type, metric_year),
    CONSTRAINT chk_metric_year      CHECK (metric_year BETWEEN 1960 AND 2100),
    CONSTRAINT chk_metric_value     CHECK (metric_value >= 0),
    CONSTRAINT fk_metric_district   FOREIGN KEY (district_id)
                                    REFERENCES Districts(district_id)
);

ALTER TABLE Citizens ADD (gender VARCHAR2(10) CHECK (gender IN ('Male', 'Female', 'Other')));

ALTER TABLE Citizens MODIFY (email VARCHAR2(150));

ALTER TABLE Service_Requests ADD CONSTRAINT chk_category_len CHECK (LENGTH(category) >= 3);

CREATE INDEX idx_citizens_aadhaar   ON Citizens(aadhaar_no);
CREATE INDEX idx_citizens_phone     ON Citizens(phone);
CREATE INDEX idx_citizens_district  ON Citizens(district_id);
CREATE INDEX idx_req_citizen        ON Service_Requests(citizen_id);
CREATE INDEX idx_req_status         ON Service_Requests(status);
CREATE INDEX idx_req_created        ON Service_Requests(created_at);
CREATE INDEX idx_cmp_citizen        ON Complaints(citizen_id);
CREATE INDEX idx_cmp_dept           ON Complaints(dept_id);
CREATE INDEX idx_cmp_status         ON Complaints(status);
CREATE INDEX idx_audit_entity       ON Audit_Log(entity_type, entity_id);
CREATE INDEX idx_metrics_district   ON Utility_Metrics(district_id, metric_year);

CREATE OR REPLACE VIEW V_Citizen_Status AS
SELECT
    c.citizen_id,
    c.first_name || ' ' || c.last_name  AS citizen_name,
    c.phone,
    d.district_name,
    'REQUEST'                           AS entity_type,
    sr.req_id                           AS entity_id,
    u.utility_type,
    dep.dept_name,
    sr.category,
    sr.status,
    sr.priority,
    sr.created_at,
    sr.updated_at
FROM Citizens c
JOIN Districts d         ON c.district_id   = d.district_id
JOIN Service_Requests sr ON sr.citizen_id   = c.citizen_id
JOIN Utilities u         ON sr.utility_id   = u.utility_id
JOIN Departments dep     ON u.dept_id       = dep.dept_id

UNION ALL

SELECT
    c.citizen_id,
    c.first_name || ' ' || c.last_name,
    c.phone,
    d.district_name,
    'COMPLAINT',
    cmp.complaint_id,
    NULL,
    dep.dept_name,
    'Complaint',
    cmp.status,
    cmp.priority,
    cmp.created_at,
    cmp.updated_at
FROM Citizens c
JOIN Districts d     ON c.district_id  = d.district_id
JOIN Complaints cmp  ON cmp.citizen_id = c.citizen_id
JOIN Departments dep ON cmp.dept_id    = dep.dept_id;

CREATE OR REPLACE VIEW V_Dept_Workload AS
SELECT
    dep.dept_name,
    COUNT(sr.req_id)                                            AS open_requests,
    COUNT(CASE WHEN sr.status = 'Escalated' THEN 1 END)        AS escalated_requests,
    ROUND(AVG(SYSDATE - CAST(sr.created_at AS DATE)), 1)       AS avg_age_days
FROM Departments dep
LEFT JOIN Utilities u         ON u.dept_id     = dep.dept_id
LEFT JOIN Service_Requests sr ON sr.utility_id = u.utility_id
                              AND sr.status NOT IN ('Resolved', 'Rejected')
GROUP BY dep.dept_name;

CREATE OR REPLACE VIEW V_District_Metrics AS
SELECT
    d.district_name,
    um.utility_type,
    um.metric_year,
    um.metric_value,
    um.unit,
    um.source
FROM Utility_Metrics um
JOIN Districts d ON um.district_id = d.district_id
ORDER BY d.district_name, um.utility_type, um.metric_year;

CREATE OR REPLACE PROCEDURE SP_Submit_Request (
    p_citizen_id    IN  NUMBER,
    p_utility_id    IN  NUMBER,
    p_category      IN  VARCHAR2,
    p_description   IN  VARCHAR2,
    p_priority      IN  VARCHAR2 DEFAULT 'Normal',
    p_req_id        OUT NUMBER
) AS
    v_citizen_count NUMBER;
    v_utility_count NUMBER;
    EX_INVALID_CITIZEN EXCEPTION;
    EX_INVALID_UTILITY EXCEPTION;
BEGIN
    SELECT COUNT(*) INTO v_citizen_count FROM Citizens WHERE citizen_id = p_citizen_id;
    IF v_citizen_count = 0 THEN RAISE EX_INVALID_CITIZEN; END IF;

    SELECT COUNT(*) INTO v_utility_count FROM Utilities WHERE utility_id = p_utility_id;
    IF v_utility_count = 0 THEN RAISE EX_INVALID_UTILITY; END IF;

    INSERT INTO Service_Requests
        (req_id, citizen_id, utility_id, category, description, priority)
    VALUES
        (seq_request.NEXTVAL, p_citizen_id, p_utility_id, p_category, p_description, p_priority)
    RETURNING req_id INTO p_req_id;

    INSERT INTO Audit_Log (entity_type, entity_id, old_status, new_status, changed_by)
    VALUES ('REQUEST', p_req_id, NULL, 'Pending', 'SP_Submit_Request');

    COMMIT;

EXCEPTION
    WHEN EX_INVALID_CITIZEN THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20001, 'Citizen ID ' || p_citizen_id || ' does not exist.');
    WHEN EX_INVALID_UTILITY THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20002, 'Utility ID ' || p_utility_id || ' does not exist.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END SP_Submit_Request;
/

CREATE OR REPLACE PROCEDURE SP_Submit_Complaint (
    p_citizen_id    IN  NUMBER,
    p_dept_id       IN  NUMBER,
    p_description   IN  VARCHAR2,
    p_priority      IN  VARCHAR2 DEFAULT 'Normal',
    p_complaint_id  OUT NUMBER
) AS
    v_citizen_count NUMBER;
    v_dept_count    NUMBER;
    EX_INVALID_CITIZEN EXCEPTION;
    EX_INVALID_DEPT    EXCEPTION;
BEGIN
    SELECT COUNT(*) INTO v_citizen_count FROM Citizens WHERE citizen_id = p_citizen_id;
    IF v_citizen_count = 0 THEN RAISE EX_INVALID_CITIZEN; END IF;

    SELECT COUNT(*) INTO v_dept_count FROM Departments WHERE dept_id = p_dept_id;
    IF v_dept_count = 0 THEN RAISE EX_INVALID_DEPT; END IF;

    INSERT INTO Complaints (complaint_id, citizen_id, dept_id, description, priority)
    VALUES (seq_complaint.NEXTVAL, p_citizen_id, p_dept_id, p_description, p_priority)
    RETURNING complaint_id INTO p_complaint_id;

    INSERT INTO Audit_Log (entity_type, entity_id, old_status, new_status, changed_by)
    VALUES ('COMPLAINT', p_complaint_id, NULL, 'Open', 'SP_Submit_Complaint');

    COMMIT;

EXCEPTION
    WHEN EX_INVALID_CITIZEN THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20005, 'Citizen ID ' || p_citizen_id || ' does not exist.');
    WHEN EX_INVALID_DEPT THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20006, 'Department ID ' || p_dept_id || ' does not exist.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END SP_Submit_Complaint;
/

CREATE OR REPLACE PROCEDURE SP_Update_Status (
    p_ref_type      IN  CHAR,
    p_ref_id        IN  NUMBER,
    p_new_status    IN  VARCHAR2,
    p_changed_by    IN  VARCHAR2 DEFAULT 'SYSTEM'
) AS
    v_old_status VARCHAR2(20);
BEGIN
    IF p_ref_type = 'REQ' THEN
        SELECT status INTO v_old_status
        FROM   Service_Requests WHERE req_id = p_ref_id
        FOR UPDATE;

        UPDATE Service_Requests
        SET    status      = p_new_status,
               updated_at  = SYSTIMESTAMP,
               resolved_at = CASE WHEN p_new_status IN ('Resolved', 'Rejected')
                             THEN SYSTIMESTAMP ELSE resolved_at END
        WHERE  req_id = p_ref_id;

    ELSIF p_ref_type = 'CMP' THEN
        SELECT status INTO v_old_status
        FROM   Complaints WHERE complaint_id = p_ref_id
        FOR UPDATE;

        UPDATE Complaints
        SET    status      = p_new_status,
               updated_at  = SYSTIMESTAMP,
               resolved_at = CASE WHEN p_new_status IN ('Resolved', 'Rejected')
                             THEN SYSTIMESTAMP ELSE resolved_at END
        WHERE  complaint_id = p_ref_id;

    ELSE
        RAISE_APPLICATION_ERROR(-20003, 'ref_type must be REQ or CMP.');
    END IF;

    INSERT INTO Audit_Log (entity_type, entity_id, old_status, new_status, changed_by)
    VALUES (CASE p_ref_type WHEN 'REQ' THEN 'REQUEST' ELSE 'COMPLAINT' END,
            p_ref_id, v_old_status, p_new_status, p_changed_by);

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20004,
            'Record not found: ' || p_ref_type || ' ' || p_ref_id);
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END SP_Update_Status;
/

CREATE OR REPLACE FUNCTION FN_Citizen_Lookup (
    p_aadhaar IN CHAR     DEFAULT NULL,
    p_phone   IN VARCHAR2 DEFAULT NULL
) RETURN NUMBER AS
    v_citizen_id NUMBER;
    EX_AMBIGUOUS_INPUT EXCEPTION;
BEGIN

    IF p_aadhaar IS NOT NULL AND p_phone IS NOT NULL THEN
        RAISE EX_AMBIGUOUS_INPUT;
    END IF;

    IF p_aadhaar IS NOT NULL THEN
        SELECT citizen_id INTO v_citizen_id
        FROM   Citizens
        WHERE  aadhaar_no = p_aadhaar;
    ELSIF p_phone IS NOT NULL THEN
        SELECT citizen_id INTO v_citizen_id
        FROM   Citizens
        WHERE  phone = p_phone;
    ELSE
        RETURN -1;  
    END IF;

    RETURN v_citizen_id;

EXCEPTION
    WHEN EX_AMBIGUOUS_INPUT THEN
        RAISE_APPLICATION_ERROR(-20030,
            'Pass either Aadhaar or phone, not both.');
    WHEN NO_DATA_FOUND THEN
        RETURN -1;
END FN_Citizen_Lookup;
/

CREATE OR REPLACE FUNCTION FN_Get_Pending_Count (
    p_citizen_id IN NUMBER,
    p_type       IN VARCHAR2 DEFAULT 'ALL'
) RETURN NUMBER AS
    v_req_count NUMBER := 0;
    v_cmp_count NUMBER := 0;
BEGIN
    IF p_type IN ('REQ', 'ALL') THEN
        SELECT COUNT(*) INTO v_req_count
        FROM   Service_Requests
        WHERE  citizen_id = p_citizen_id
          AND  status NOT IN ('Resolved', 'Rejected');
    END IF;

    IF p_type IN ('CMP', 'ALL') THEN
        SELECT COUNT(*) INTO v_cmp_count
        FROM   Complaints
        WHERE  citizen_id = p_citizen_id
          AND  status NOT IN ('Resolved', 'Rejected');
    END IF;

    RETURN v_req_count + v_cmp_count;
END FN_Get_Pending_Count;
/

CREATE OR REPLACE TRIGGER TRG_Receipt_Auto_Req
AFTER INSERT ON Service_Requests
FOR EACH ROW
BEGIN
    INSERT INTO Receipts (ref_type, ref_id, citizen_id, details)
    VALUES ('REQ', :NEW.req_id, :NEW.citizen_id,
            'Service Request #' || :NEW.req_id ||
            ' | Category: '     || :NEW.category ||
            ' | Status: Pending | Created: ' ||
            TO_CHAR(SYSTIMESTAMP, 'DD-MON-YYYY HH24:MI'));
END TRG_Receipt_Auto_Req;
/

CREATE OR REPLACE TRIGGER TRG_Receipt_Auto_Cmp
AFTER INSERT ON Complaints
FOR EACH ROW
BEGIN
    INSERT INTO Receipts (ref_type, ref_id, citizen_id, details)
    VALUES ('CMP', :NEW.complaint_id, :NEW.citizen_id,
            'Complaint #'  || :NEW.complaint_id ||
            ' | Dept ID: ' || :NEW.dept_id ||
            ' | Status: Open | Created: ' ||
            TO_CHAR(SYSTIMESTAMP, 'DD-MON-YYYY HH24:MI'));
END TRG_Receipt_Auto_Cmp;
/

CREATE OR REPLACE TRIGGER TRG_Complaint_Dup_Check
BEFORE INSERT ON Complaints
FOR EACH ROW
DECLARE
    v_dup_count NUMBER;
    EX_DUPLICATE_COMPLAINT EXCEPTION;
BEGIN
    SELECT COUNT(*) INTO v_dup_count
    FROM   Complaints
    WHERE  citizen_id         = :NEW.citizen_id
      AND  dept_id            = :NEW.dept_id
      AND  status NOT IN ('Resolved', 'Rejected')
      AND  UPPER(description) = UPPER(:NEW.description);

    IF v_dup_count > 0 THEN RAISE EX_DUPLICATE_COMPLAINT; END IF;

EXCEPTION
    WHEN EX_DUPLICATE_COMPLAINT THEN
        RAISE_APPLICATION_ERROR(-20010,
            'Duplicate complaint: an identical open complaint already exists for this citizen.');
END TRG_Complaint_Dup_Check;
/

CREATE OR REPLACE TRIGGER TRG_Audit_Request_Status
AFTER UPDATE OF status ON Service_Requests
FOR EACH ROW
WHEN (OLD.status <> NEW.status)
BEGIN
    INSERT INTO Audit_Log (entity_type, entity_id, old_status, new_status, changed_by)
    VALUES ('REQUEST', :NEW.req_id, :OLD.status, :NEW.status, 'TRIGGER');
END TRG_Audit_Request_Status;
/

CREATE OR REPLACE TRIGGER TRG_Audit_Complaint_Status
AFTER UPDATE OF status ON Complaints
FOR EACH ROW
WHEN (OLD.status <> NEW.status)
BEGIN
    INSERT INTO Audit_Log (entity_type, entity_id, old_status, new_status, changed_by)
    VALUES ('COMPLAINT', :NEW.complaint_id, :OLD.status, :NEW.status, 'TRIGGER');
END TRG_Audit_Complaint_Status;
/

CREATE OR REPLACE TRIGGER TRG_Audit_Log_Protect
BEFORE UPDATE OR DELETE ON Audit_Log
FOR EACH ROW
BEGIN
    RAISE_APPLICATION_ERROR(-20020,
        'Audit_Log is append-only. UPDATE and DELETE are not permitted.');
END TRG_Audit_Log_Protect;
/
CREATE OR REPLACE TRIGGER TRG_Doc_Ref_Check
BEFORE INSERT OR UPDATE ON Documents
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    IF :NEW.ref_type = 'REQ' THEN
        SELECT COUNT(*) INTO v_count FROM Service_Requests WHERE req_id = :NEW.ref_id;
    ELSE
        SELECT COUNT(*) INTO v_count FROM Complaints WHERE complaint_id = :NEW.ref_id;
    END IF;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20011,
            'Document ref_id ' || :NEW.ref_id ||
            ' not found in ' || :NEW.ref_type || ' table.');
    END IF;
END TRG_Doc_Ref_Check;
/

CREATE OR REPLACE PROCEDURE SP_Escalate_Overdue AS
    CURSOR CUR_Overdue_Requests IS
        SELECT sr.req_id,
               sr.status,
               u.sla_days,
               ROUND(SYSDATE - CAST(sr.created_at AS DATE)) AS age_days
        FROM   Service_Requests sr
        JOIN   Utilities u ON sr.utility_id = u.utility_id
        WHERE  sr.status IN ('Pending', 'In Progress')
          AND  SYSDATE - CAST(sr.created_at AS DATE) > u.sla_days;

    v_escalated NUMBER := 0;
BEGIN
    FOR rec IN CUR_Overdue_Requests LOOP
        SAVEPOINT before_row;
        BEGIN
            UPDATE Service_Requests
            SET    status     = 'Escalated',
                   updated_at = SYSTIMESTAMP
            WHERE  req_id = rec.req_id;

            INSERT INTO Audit_Log
                (entity_type, entity_id, old_status, new_status, changed_by, remarks)
            VALUES
                ('REQUEST', rec.req_id, rec.status, 'Escalated', 'CUR_Overdue_Requests',
                 'SLA breached: ' || rec.age_days || ' days > SLA ' || rec.sla_days || ' days');

            v_escalated := v_escalated + 1;

        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK TO before_row;
                DBMS_OUTPUT.PUT_LINE('Failed to escalate REQ ' || rec.req_id || ': ' || SQLERRM);
        END;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Escalation complete. Total escalated: ' || v_escalated);
END SP_Escalate_Overdue;
/

SELECT entity_type, entity_id, dept_name, utility_type, status, priority, created_at
FROM   V_Citizen_Status
WHERE  citizen_id = :citizen_id
  AND  status NOT IN ('Resolved', 'Rejected')
ORDER  BY created_at DESC;

SELECT dep.dept_name,
       COUNT(c.complaint_id)                                     AS total_complaints,
       COUNT(CASE WHEN c.status = 'Open' THEN 1 END)            AS open_complaints,
       ROUND(AVG(CASE WHEN c.resolved_at IS NOT NULL
                 THEN CAST(c.resolved_at AS DATE) - CAST(c.created_at AS DATE)
                 END) * 24, 1)                                   AS avg_resolution_hrs
FROM   Departments dep
LEFT   JOIN Complaints c ON c.dept_id = dep.dept_id
GROUP  BY dep.dept_name
HAVING COUNT(c.complaint_id) > 0
ORDER  BY open_complaints DESC;

SELECT c.first_name || ' ' || c.last_name                       AS citizen,
       c.phone,
       d.district_name,
       (SELECT COUNT(*) FROM Complaints cmp
        WHERE  cmp.citizen_id = c.citizen_id
          AND  cmp.status NOT IN ('Resolved', 'Rejected')
          AND  SYSDATE - CAST(cmp.created_at AS DATE) > 7)      AS overdue_complaints
FROM   Citizens c
JOIN   Districts d ON c.district_id = d.district_id
WHERE  (SELECT COUNT(*) FROM Complaints cmp
        WHERE  cmp.citizen_id = c.citizen_id
          AND  cmp.status NOT IN ('Resolved', 'Rejected')
          AND  SYSDATE - CAST(cmp.created_at AS DATE) > 7) > 0;

SELECT d.district_name,
       m20.metric_value                                          AS waste_2020,
       m22.metric_value                                          AS waste_2022,
       ROUND((m22.metric_value - m20.metric_value)
             / m20.metric_value * 100, 2)                        AS pct_growth
FROM   Districts d
JOIN   Utility_Metrics m20 ON m20.district_id  = d.district_id
                           AND m20.utility_type = 'Municipal Waste Generated'
                           AND m20.metric_year  = 2020
JOIN   Utility_Metrics m22 ON m22.district_id  = d.district_id
                           AND m22.utility_type = 'Municipal Waste Generated'
                           AND m22.metric_year  = 2022
ORDER  BY pct_growth DESC;

SELECT FN_Get_Pending_Count(:citizen_id, 'ALL') AS total_pending FROM DUAL;

SELECT log_id, old_status, new_status, changed_by, changed_at, remarks
FROM   Audit_Log
WHERE  entity_type = 'REQUEST'
  AND  entity_id   = :req_id
ORDER  BY changed_at ASC;

CREATE TABLE Waste_Temp (
    district    VARCHAR2(50),
    year        NUMBER,
    generated   NUMBER,
    treated     NUMBER
);

CREATE TABLE Electricity_Temp (
    district                VARCHAR2(50),
    year                    NUMBER,
    domestic_connections    NUMBER
);

INSERT INTO Utility_Metrics (district_id, utility_type, metric_year, metric_value, unit)
SELECT d.district_id, 'Municipal Waste Generated', w.year, w.generated, 'metric_tons'
FROM   Waste_Temp w
JOIN   Districts d ON LOWER(w.district) = LOWER(d.district_name);

INSERT INTO Utility_Metrics (district_id, utility_type, metric_year, metric_value, unit)
SELECT d.district_id, 'Municipal Waste Treated', w.year, w.treated, 'metric_tons'
FROM   Waste_Temp w
JOIN   Districts d ON LOWER(w.district) = LOWER(d.district_name);

INSERT INTO Utility_Metrics (district_id, utility_type, metric_year, metric_value, unit)
SELECT d.district_id, 'Electricity Connections', e.year, e.domestic_connections, 'connections'
FROM   Electricity_Temp e
JOIN   Districts d ON LOWER(e.district) = LOWER(d.district_name);

COMMIT;


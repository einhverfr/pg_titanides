CREATE OR REPLACE FUNCTION pgt_add_queue(in_queuename text, in_classname text, in_language text)
RETURNS pt_queues LANGUAGE PLPGSQL AS
$$
DECLARE retval pt_queues;
        qid int;
BEGIN
    INSERT INTO pt_queues (queue_name, classname, language)
    VALUES ($1, $2, $3)
    RETURNING id INTO qid;

    EXECUTE $E$
        CREATE TABLE pt_jobs_$E$ || qid::text || $E$
	   (LIKE pt_jobtemplate INCLUDING ALL,
	    CHECK queue_id = $E$ || qid || $E$) INHERITS (pt_jobtemplate) $E$;
    SELECT * FROM pt_queues INTO retval WHERE id = qid;

    RETURN retval;
$$;

CREATE OR REPLACE FUNCTION pgt_get_jobs(in_qid, in_batch_size)
RETURNS SETOF pt_jobtemplate
LANGUAGE PLPGSQL AS
$$
DECLARE outrow pt_jobtemplate;
 locktest bool;
 rows_returned int;
 startpoint int;
 gotpriority bool;
BEGIN
    SELECT pg_try_advisory_lock('pt_queues'::regclass::oid::int, in_qid) 
      INTO gotpriority;

    IF locktest THEN -- priority scan
        jobcurs CURSOR FOR EXECUTE $E$
        SELECT * FROM pt_jobs_$E$ || in_qid::text 
	|| $E$ ORDER BY priority asc $E$;
    ELSE -- grab random point from histogram and go forward
        SELECT histogram[...] INTO startpoint
	  FROM pg_stats
	 WHERE ....;

	jobcurs CURSOR FOR EXECUTE $E$
        SELECT * FROM pt_jobs_$E$ || in_qid::text 
	|| $E$ WHERE ID > $1 ORDER BY id asc $E$ using startpoint;
    END IF;

    LOOP
        FETCH FROM jobcurs INTO outrow;
        IF outrow IS NULL THEN
           RETURN;
        END IF;
        IF .... THEN
           rows_returned := rows_returned + 1;
           RETURN NEXT outrow;
        END IF;
        IF rows_returned >= in_batch_size THEN
           RETURN;
        END IF;
    END LOOP;
END;
$$;

CREATE OR REPLCE FUNCTION pgt_fail_job(in_jobid bigint, in_message text, in_qid int)
RETURNS TIMESTAMP LANGAUGE PLPGSQL AS
$$
DECLARE sec_delay interval;
BEGIN
    EXECUTE $e$
    INSERT INTO pt_error (job_id, queue_id, args, message)
    SELECT id, queue_id, args, $2
      FROM pt_jobs_$e$ || in_qid::text || $E$
     WHERE id = $1 $E$ USING in_jobid, in_message;

    SELECT count(*) ^ 2 INTO sec_delay
      FROM pt_error WHERE queue_id = in_qid AND jobid = in_jobid;

    EXECUTE $E$
    UPDATE pt_jobs_$E$ || in_qid::text || $E$
       SET run_after = now() + ?
     WHERE id = ? $E$ USING ((sec_delay::text || ' seconds')::interval, in_jobid);

    RETURN now() + (sec_delay::text || ' seconds')::interval;
END;
$$;

CREATE OR REPLACE FUNCTION pgt_recheck_jobs(jobids bigint[], in_qid int)
RETURNS bigint[] LANGUAGE PLPGSQL AS $$
DECLARE retval bigint[];

BEGIN
EXECUTE $E$SELECT array_agg(id) into retval
  FROM pt_jobs_$E$ || in_qid::text || $E$
 WHERE id = ANY($1) $E$ USING jobids;

RETURN retval;
END;
$$;

CREATE OR REPLACE FUNCTION pgt_complete_job(in_jobid bigint, in_qid int)
RETURNS BOOL LANGUAGE PLPGSQL AS
$$
BEGIN
EXECUTE $E$
DELETE
  FROM pt_jobs_$E$ || in_qid::text || $E$
 WHERE id = $1 $E$ USING in_jobid;

RETURN FOUND

END;
$$;

CREATE OR REPLACE FUNCTION pgt_finish_batch() RETURNS VOID LANGUAGE SQL AS
$$
select pg_advisory_unlock_all();
$$;

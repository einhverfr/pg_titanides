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
	   (LIKE pt_jobtemplate INCLUDING ALL) INHERITS (pt_jobtemplate) $E$;
    SELECT * FROM pt_queues INTO retval WHERE id = qid;
    RETURN retval;
$$;

CREATE OR REPLACE FUNCTION pgt_get_jobes(in_qid, in_batch_size)
RETURNS SETOF pt_jobtemplate
LANGUAGE PLPGSQL AS
$$
DECLARE outrow pt_jobtemplate;
BEGIN
	-- try to get advisory lock for priority scan
	-- declare cursor
	-- loop through cursor, trying job advisory locks
END;
$$;

CREATE OR REPLACE FUNCTION pgt_recheck_jobs(jobids bigint[], in_qid int)
RETURNS bigint[] LANGUAGE PLPGSQL AS $$
DECLARE retval bigint[];

BEGIN
EXECUTE $E$SELECT array_agg(id) into retval
  FROM pt_jobs_$E$ || in_qid::text || $E$
 WHERE id = ANY($1) $E$ USING jobids1;

RETURN retval;
END;
$$;

CREATE OR REPLACE FUNCTION pgt_finish_batch() RETURNS VOID LANGUAGE SQL AS
$$
select pg_advisory_unlock_all();
$$;

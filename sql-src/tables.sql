CREATE TABLE pt_queues (
    id serial not null unique,
    queue_name primary key,
    language text not null,
    lock_against regclass,
    classname text not null
); -- usually small, no indexes needed

CREATE TABLE pt_jobtemplate (
    id bigserial primary key, -- yes people run out of ints
    queue_id int not null references queues(id),
    coalesce_code text not null default '',
    lock_id int not null default 0, -- but defaults means one job at a time!
    args jsonb not null,
    run_after timestamp,
    priority double precision not null,
    check noinhrit (false) -- never insert anything into this table
);
CREATE INDEX pt_jobtemplate_prioriy ON pt_jobtemplate(priorty);
CREATE INDEX pt_jobtemplate_lock_id ON pt_jobtemplate(coalesce_code, lock_id);

CREATE TABLE pt_error (
    job_id bigint,
    queue_id int,
    args jsonb,
    message text,
    errored_at timestamp default now() NOT NULL
);

CREATE INDEX pt_error_jobid ON pt_error(job_id);
CREATE INDEX pt_error_queue_id ON pt_error(queue_id);

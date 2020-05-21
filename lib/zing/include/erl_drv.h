#ifndef ERL_DRV_H
#define ERL_DRV_H

// Temporary shim to uncover deficiencies in Zigler externs

typedef unsigned long long uint64_t;

typedef struct ErlDrvTid_ *ErlDrvTid;

typedef struct {
    int suggested_stack_size;
} ErlDrvThreadOpts;

extern int erl_drv_thread_create(
    const char *name,
    ErlDrvTid *tid,
    void * (*func)(void *),
    void * arg,
    ErlDrvThreadOpts *opts);

struct enif_environment_t;
typedef struct enif_environment_t ErlNifEnv;
typedef uint64_t ErlNifTerm;

typedef struct
{
    ErlNifTerm pid;  /* internal, may change */
} ErlNifPid;

extern int enif_is_process_alive(
  ErlNifEnv *env,
  ErlNifPid *pid);

#endif

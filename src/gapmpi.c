/****************************************************************************
**
*W  gapmpi.c            GAP source - ParGAP/MPI hooks          Gene Cooperman
**
*Y  Copyright (C) 1999-2001  Gene Cooperman
*Y    See included file, COPYING, for conditions for copying
**
**  ParGAP/MPI
**  Primary hooks into GAP (called from gap.c):
**    InitPargapmpi(), InitInfoPargapmpi -> InitLibrary()
**    InitPargapmpi() exits immediately, if GAP not called as pargapmpi
*/

/***** core GAP includes *****/

#include "gap_all.h"
#include "sysopt.h"

#include "gapmpi.h" /* MPI functions and UNIX utils   */
#include <mpi.h>    /* provided with MPI distribution */

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

/*====================================================================
 * Internal UNIX utilities
 * These utilities are provided to be used at GAP level, and are not
 *   easily duplicated with current GAP facilities.
 */

Obj UNIX_MakeString(Obj self, Obj len)
{
  return NEW_STRING(INT_INTOBJ(len));
}

#if 0
Obj ParGAP_Last( Obj self )
{ return VAL_GVAR( Last );
}
#endif

Obj UNIX_Chdir(Obj self, Obj string)
{
  int result;
  ConvString(string);
  result = chdir((char *)CSTR_STRING(string));
  if (result == -1) {
    fprintf(stderr, "UNIX_Chdir: %s\n", (char *)CSTR_STRING(string));
    perror("UNIX_Chdir");
  }
  return (0 == result ? True : False);
}

Obj UNIX_FflushStdout(Obj self)
{
  Pr("%c", (Int)'\03', 0L);
  return 0;
}

Obj UNIX_Getpid(Obj self)
{
  return INTOBJ_INT(getpid());
}

Obj UNIX_Hostname(Obj self)
{
  char buf[100];
  int  res;
  res = gethostname(buf, 100);
  if (res == -1) {
    perror("UNIX_Hostname: ");
    sprintf(buf, "<unknown name>");
  }
  return MakeString(buf);
}

Obj UNIX_Realtime(Obj self) /* Time since beginning in seconds */
{
  static time_t time_since_start = -1;
  if (time_since_start == (time_t)-1)
    time_since_start = time(NULL);
  /* Some non-POSIX UNIX's could have problem with the S-2^31 problem. :-) */
  return INTOBJ_INT(time(NULL) - time_since_start);
}

Obj UNIX_Alarm(Obj self, Obj seconds)
{
  if (seconds > 0)
    Pr("This process will die in %d seconds.  Call with arg, 0, to cancel.\n",
       INT_INTOBJ(seconds), 0L);
  else
    Pr("Alarm cancelled", 0L, 0L);
  return INTOBJ_INT(alarm(INT_INTOBJ(seconds)));
}

/* Changes priority to value of -20 to 20.  higher means lower priority.
 * initial default is priority 0.  Result is previous value of priority.
 */
Obj UNIX_Nice(Obj self, Obj prio)
{
  int oldprio, success;
  oldprio = getpriority(PRIO_PROCESS, getpid());
  success = setpriority(PRIO_PROCESS, getpid(), INT_INTOBJ(prio));
  if (success == -1) {
    perror("UNIX_Nice");
    return Fail;
  }
  return INTOBJ_INT(oldprio);
}

/* Changes RSS (Resident Set Size) limit (in bytes) and returns last setting.
 * Try "ps -elf" or "man ps" for description of RSS.
 * Try "limit" under csh or "ulimit -a" under bash.
 */
Obj UNIX_LimitRss(Obj size) /* size in units of bytes */
{
  Int           oldsize;    /* GAP Int is long, and many UNIX's use long */
  int           success;
  struct rlimit rlp;
#ifdef RLIMIT_RSS
  getrlimit(RLIMIT_RSS, &rlp);
  success = getrlimit(RLIMIT_RSS, &rlp);
  if (success == -1) {
    perror("UNIX_LimitRss");
    return Fail;
  }
  oldsize = rlp.rlim_cur;
  rlp.rlim_cur = INT_INTOBJ(size);
  success = setrlimit(RLIMIT_RSS, &rlp);
  if (success == -1) {
    perror("UNIX_LimitRss");
    return Fail;
  }
  return INTOBJ_INT(oldsize);
#else
  Pr("WARNING:  UNIX_LimitRss:  Not supported in this version of UNIX\n", 0L,
     0L);
  return Fail;
#endif
}


/*====================================================================
 * ParGAP/MPI issues of signals and interrupts
 */

/* There are three potential signal handlers:
 *  syAnswerIntr():  GAP default signal handler
 *  ParGAPAnswerIntr():  ParGAP/MPI signal handler installed only during
 *			MPI_Probe(), MPI_Recv(), etc.
 *			On a slave, it is installed permanently.
 *                      It calls syAnswerIntr(), allowing GAP to do any
 *            		bookkeeping of GAP data struct's, and longjmp's.
 *  null_handler():  in MPINU, used around call to select(), to cleanly
 *	   come out of a blocking system call that was interrupted (EINTR),
 *         then raise previous signal handler,
 *         and then try system call again (assuming no interim longjmp)
 *         Ideally, all MPI implementations would do something like this,
 *         but many MPI implementations were not designed to handle
 *interrupts.
 */

/***********************************************************************
 *                ANALYSIS OF GAP'S INTERRUPT HANDLER
 * sysfiles.c:syAnswerIntr() -> stats.c:InterruptExecStat();
 *    which changes statement dispatch table to all:  ExecIntrStat();
 *   Then wait for next statement dispatch:
 *  stats.c:ExecIntrStat()
 *    -> [restore dispatch table, sysfiles.c:SyIsIntr();
 *       ErrorReturnVoid(); return EXEC_STAT(stat) ]
 *  ErrorReturnVoid() -> gap.c:ErrorMode() -> ReadEvalError() ->
 *          longjmp(ReadJmpError)
 * if (UserHasQUIT)
 *	  break;
 * else if ( status & (STATUS_EOF | STATUS_QUIT | STATUS_QQUIT) ) {
 *          break;
 * status == STATUS_EOF  coming from ReadEvalCommand() or ReadEvalFile()
 *   -> if ( ! BreakOnError ) ReadEvalError();
 * [ Note:  BreakOnError is set to 0 on all slaves ]
 *
 * If syAnswerIntr() throws to TRY_IF_NO_ERROR()
 * we'll reach MPI_READ_DONE() and restore the previous signal.
 */

/* This part copied from src/sysfiles.c */
#ifndef SYS_SIGNAL_H /* signal handling functions       */
#include <signal.h>
#ifdef SYS_HAS_SIG_T
#define SYS_SIG_T SYS_HAS_SIG_T
#else
#define SYS_SIG_T void
#endif
#define SYS_SIGNAL_H
typedef SYS_SIG_T sig_handler_t(int);
SYS_SIG_T         syAnswerIntr(int signr);
#endif

static SYS_SIG_T (*savedSignal)(int);
static jmp_buf readJmpError; /* TOP level => non-reentrant */
#define MPI_READ_INIT()                                                      \
  do {                                                                       \
    memcpy(readJmpError, STATE(ReadJmpError), sizeof(jmp_buf));              \
    savedSignal = signal(SIGINT, &ParGAPAnswerIntr);                         \
  } while (0)
#define MPI_READ_DONE()                                                      \
  do {                                                                       \
    signal(SIGINT, savedSignal);                                             \
    memcpy(STATE(ReadJmpError), readJmpError, sizeof(jmp_buf));              \
  } while (0)

SYS_SIG_T ParGAPAnswerIntr(int signr)
{
  Obj MPIcomm_rank(Obj self);
#if defined(DEBUG)
  Pr("Rank(%d): Inside ParGAPAnswerIntr\n", INT_INTOBJ(MPIcomm_rank((Obj)0)),
     0L);
  printf("  ParGAPAnswerIntr:  %x;  syAnswerIntr:  %x\n", ParGAPAnswerIntr,
         syAnswerIntr);
#endif
  /* syAnswerIntr() will register that an interrupt has occurred.
     A slave doesn't need to know it.
  */
  if (0 == INT_INTOBJ(MPIcomm_rank((Obj)0))) {
    syAnswerIntr(signr);
#if defined(DEBUG)
    Pr("Rank(%d): Called syAnswerIntr( %d ) and returned.\n",
       INT_INTOBJ(MPIcomm_rank((Obj)0)), signr);
#endif
  }
  /* This signal() is needed if we're not throwing to TRY_IF_NO_ERROR() */
  signal(SIGINT, ParGAPAnswerIntr);
  /* ReadEvalError() will throw to TRY_IF_NO_ERROR() if this was called
      after TRY_IF_NO_ERROR() in gapmpi.c;  (It should have been.)
     In MPINU on slave, we simply exit select(), discover EINTR, and
      return to select().  (We don't yet longjmp() to the recv-eval-send
      loop on slave.)
  */
  ReadEvalError(); /* throw to TRY_IF_NO_ERROR() */
  /*NOTREACHED*/
#if defined(SYS_HAS_SIG_T) && !HAVE_SIGNAL_VOID
  return 0; /* is ignored                      */
#endif
}

/* Catches interrupts (SIGINT) and UNIX_Throw() */
/* Note that if desired, one can also catch all errors by adding
    by adding a global variable, IntrCatching, and within UNIX_Catch():
      Uint intrCatching = IntrCatching;
      ...
      IntrCatching = intrCatching;
   Then upon entering
    src/gap.c:ErrorMode(), do UNIX_Throw()
   In this case, the slave wouldn't need to set BreakOnError = 0
*/
Obj UNIX_Catch(Obj self, Obj fnc, Obj arg2)
{
  Obj result; /* gcc -Wall complains if result is initialized to Fail here */
  Bag currLVars = STATE(CurrLVars);
  jmp_buf readJmpError;
  SYS_SIG_T (*savedSignal)(int);

  result = Fail;
  MPI_READ_INIT();
  TRY_IF_NO_ERROR
  {
    result = CallFuncList(fnc, arg2);
  }
  CATCH_ERROR
  {
    while (STATE(CurrLVars) != currLVars &&
           STATE(CurrLVars) != STATE(BottomLVars))
      SWITCH_TO_OLD_LVARS(PARENT_LVARS(STATE(CurrLVars)));
    assert(STATE(CurrLVars) == currLVars);
    ClearError();
    SyIsIntr(); /* clear the interrupt, too */
  }
  MPI_READ_DONE();

  return result;
}

/* Raise a SIGINT, that should be caught by UNIX_Catch() */
Obj UNIX_Throw(Obj self)
{
  kill(getpid(), SIGINT);
  /* NOTREACHED */
  return self;
}

/*====================================================================
 * Support for MPI functions
 * These will either disappear, or move to next section:  MPI functions
 */

#define UNINITIALIZED                                                        \
  ((MPI_Datatype)-1) /* must be distinct from all MPI datatypes */

static MPI_Status   last_status;
static MPI_Datatype last_datatype =
    UNINITIALIZED; /* needed for MPIget_count */

MPI_Datatype MPIdatatype_infer(Obj object)
{
  if (IS_STRING(object))
    return MPI_CHAR;
  /* Maybe any other kind of GAP list should assume a list of int's coming */
  if (IS_HOMOG_LIST(object) && IS_INTOBJ(ELM_LIST(object, 1)))
    return MPI_INT;
  ErrorQuit(
      "bad vector passed for message handling; must be string or gen. vec.",
      0L, 0L);
  return 0;
}

/*====================================================================
 * MPI functions
 * These functions are made available to GAP level.
 * At GAP level, they will use the same name as the original MPI functions,
 *   but their functionality is modified to a more convenient one for
 *   an interactive language.
 * Most of these functions will not be called directly by an application
 *   writer.  For an application interface, see slavelist.g and masslave.g
 */

/* Macro to do standard argument checking for C implementation of GAP fnc */
#define MPIARGCHK(min, max, error)                                           \
  if (!IS_LIST(args) || LEN_LIST(args) > max || LEN_LIST(args) < min) {      \
    ErrorQuit("usage:  " error, 0L, 0L);                                     \
    return 0;                                                                \
  }

Obj MPIinit(Obj self)
{
  int     MPIargc;
  char ** MPIargv;

#ifdef DEBUG
  {
    int i;
    Pr("\n");
    for (i = 0; i < MPIargc; i++)
      Pr("%s ", MPIargv[i]);
    Pr("\n");
  }
#endif
  {
    int tst;
    MPI_Initialized(&tst);
    if (tst) {
      Pr("MPI_Init() already initialized.\n", 0L, 0L);
      return False;
    }
  }
  MPI_Init(&MPIargc, &MPIargv);
  /* Init_MPIvars(); called from InitLibrary() */
  return True;
}

Obj MPIinitialized(Obj self)
{
  int tst;
  MPI_Initialized(&tst);
  return tst ? True : False;
}

Obj MPIfinalize(Obj self)
{
  MPI_Finalize();
  return 0;
}

Obj MPIcomm_rank(Obj self)
{
  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  return INTOBJ_INT(rank);
}

/* This assumes same datatype units as last receive, or MPI_CHAR if no recv */
Obj MPIget_count(Obj self)
{
  int count;
  if (last_datatype == UNINITIALIZED)
    last_datatype = MPI_CHAR;
  MPI_Get_count(&last_status, last_datatype, &count);
  return INTOBJ_INT(count);
}
Obj MPIget_source(Obj self)
{
  return INTOBJ_INT(last_status.MPI_SOURCE);
}
Obj MPIget_tag(Obj self)
{
  return INTOBJ_INT(last_status.MPI_TAG);
}

Obj MPIcomm_size(Obj self)
{
  int size;
  MPI_Comm_size(MPI_COMM_WORLD, &size);
  return INTOBJ_INT(size);
}
Obj MPIworld_size(Obj self)
{
  return MPIcomm_size(self);
}

Obj MPIerror_string(Obj self, Obj errorcode)
{
  int resultlen;
  Obj str;
  str = NEW_STRING(72);
  MPI_Error_string(INT_INTOBJ(errorcode), (char *)CSTR_STRING(str),
                   &resultlen);
  ((char *)CSTR_STRING(str))[resultlen] = '\0';
  SET_LEN_STRING(str, resultlen);
  ResizeBag(str, SIZEBAG_STRINGLEN(GET_LEN_STRING(str)));
  return str;
}

Obj MPIget_processor_name(Obj self)
{
  int resultlen;
  Obj str;
  /* It was reported by Frank Celler that a value of 72 instead of 1024 below
     caused overwriting of the free block list on PC in GAP-3 */
  str = NEW_STRING(1024);
  MPI_Get_processor_name((char *)CSTR_STRING(str), &resultlen);
  ((char *)CSTR_STRING(str))[resultlen] = '\0';
  SET_LEN_STRING(str, resultlen);
  ResizeBag(str, SIZEBAG_STRINGLEN(GET_LEN_STRING(str)));
  return str;
}

Obj MPIattr_get(Obj self, Obj keyval)
{
  void * attribute_val;
  int    flag = 1;
  /* hd1 = MPI_IO -> can also return MPI_ANY_SOURCE / MPI_PROC_NULL */
  MPI_Attr_get(MPI_COMM_WORLD, INT_INTOBJ(keyval), &attribute_val, &flag);
  /* if (INT_INTOBJ(keyval) == MPI_HOST) flag = 0; */
  if (!flag)
    return False;
  return INTOBJ_INT(attribute_val);
}


Obj MPIabort(Obj self, Obj errorcode)
{
  MPI_Abort(MPI_COMM_WORLD, INT_INTOBJ(errorcode));
  return 0;
}

Obj MPIsend(Obj self, Obj args)
{
  Obj buf, dest, tag;
  MPIARGCHK(2, 3,
            "MPI_Send( <string buf>, <int dest>[, <opt int tag = 0> ] )");
  buf = ELM_LIST(args, 1);
  dest = ELM_LIST(args, 2);
  tag = (LEN_LIST(args) > 2 ? ELM_LIST(args, 3) : 0);
  ConvString(buf);
  MPI_Send(CSTR_STRING(buf), strlen(CSTR_STRING(buf)), /* don't incl. \0 */
           MPIdatatype_infer(buf), INT_INTOBJ(dest), INT_INTOBJ(tag),
           MPI_COMM_WORLD);
  return 0;
}

Obj MPIrecv(Obj self, Obj args)
{
  volatile Obj buf, source, tag; /* volatile to satisfy gcc compiler */
  MPIARGCHK(1, 3,
            "MPI_Recv( <string buf>, <opt int source = MPI_ANY_SOURCE>[, "
            "<opt int tag = MPI_ANY_TAG> ] )");
  buf = ELM_LIST(args, 1);
  source =
      (LEN_LIST(args) > 1 ? ELM_LIST(args, 2) : INTOBJ_INT(MPI_ANY_SOURCE));
  tag = (LEN_LIST(args) > 2 ? ELM_LIST(args, 3) : INTOBJ_INT(MPI_ANY_TAG));
  if (!IS_STRING(buf))
    ErrorQuit("MPI_Recv():  received a buffer that is not a string", 0L, 0L);
  ConvString(buf);
  /* Note GET_LEN_STRING() returns GAP string length
         and strlen(CSTR_STRING()) returns C string length (up to '\0') */
  MPI_READ_INIT();
  TRY_IF_NO_ERROR
  {
    MPI_Recv(CSTR_STRING(buf), GET_LEN_STRING(buf),
             last_datatype = MPIdatatype_infer(buf), INT_INTOBJ(source),
             INT_INTOBJ(tag), MPI_COMM_WORLD, &last_status);
  }
  MPI_READ_DONE();
  if (!IS_STRING(buf)) { /* CLEAN THIS UP LATER */
    ErrorQuit("ParGAP: panic: MPI_Recv():  result buffer is not a string", 0L,
              0L);
    exit(1);
  }
#if 0
  settimer("autologout");
#endif
  /* if (last_datatype != MPI_CHAR) {
       MPI_Get_count(&last_status, last_datatype, &count); etc. } */
  return buf;
}

Obj MPIprobe(Obj self, Obj args)
{
  volatile Obj source, tag; /* volatile to satisfy gcc compiler */
  MPIARGCHK(0, 2,
            "MPI_Probe( <opt int source = MPI_ANY_SOURCE>[, <opt int tag = "
            "MPI_ANY_TAG> ] )");
  source =
      (LEN_LIST(args) > 0 ? ELM_LIST(args, 1) : INTOBJ_INT(MPI_ANY_SOURCE));
  tag = (LEN_LIST(args) > 1 ? ELM_LIST(args, 2) : INTOBJ_INT(MPI_ANY_TAG));
  MPI_READ_INIT();
  TRY_IF_NO_ERROR
  {
    MPI_Probe(INT_INTOBJ(source), INT_INTOBJ(tag), MPI_COMM_WORLD,
              &last_status);
  }
  MPI_READ_DONE();
  return True;
}

Obj MPIiprobe(Obj self, Obj args)
{
  int          flag;
  volatile Obj source, tag; /* volatile to satisfy gcc compiler */
  MPIARGCHK(0, 2,
            "MPI_Iprobe( <opt int source = MPI_ANY_SOURCE>[, <opt int tag = "
            "MPI_ANY_TAG> ] )");
  source =
      (LEN_LIST(args) > 0 ? ELM_LIST(args, 1) : INTOBJ_INT(MPI_ANY_SOURCE));
  tag = (LEN_LIST(args) > 1 ? ELM_LIST(args, 2) : INTOBJ_INT(MPI_ANY_TAG));
  MPI_READ_INIT();
  TRY_IF_NO_ERROR
  {
    MPI_Iprobe(INT_INTOBJ(source), INT_INTOBJ(tag), MPI_COMM_WORLD, &flag,
               &last_status);
  }
  MPI_READ_DONE();
  return (flag ? True : False);
}

/*====================================================================
 * Initialization of ParGAP/MPI
 * There are two entry points for initialization.
 * InitPargapmpi() is called early in gap.c:main() and modifies
 *   argc, argv, BreakOnError, SyBanner, SyQuiet, etc.
 *   Most of the modifications are executed only on the slaves.
 * InitInfoPargapmpi() is the traditional GAP-4 module interface, and is
 *   invoked later in gap.c via InitFuncsBuiltinModules[].
 *   It invokes InitLibrary(), which invokes Init_MPIvars(), defined below.
 *   It modifies GAP only if MPI_Initialized() is true.
 * Note that ParGAP/MPI shutdown is handled via GAP's InstallAtExit()
 *   from within slavelist.g
 */

/* called _before_ GAP system initialization to remove command lines, etc. */
void InitPargapmpi(int * argc_ptr, char *** argv_ptr)
{
  char *cmd = (*argv_ptr)[0], *tmp;

  /* Unless this binary is called as .../pargapmpi, we return immediately;
     In that case, InitLibrary() will note MPI_Initialized() is false,
       and will not install UNIX functions
  */
  for (tmp = cmd; *tmp != '\0'; tmp++)
    if (*tmp == '/')
      cmd = tmp + 1;
  if (0 != strcmp("pargapmpi", cmd))
    return;

  if (0 != MPI_Init(argc_ptr, argv_ptr)) {
    fputs("ParGAP:  panic:  couldn't initialize MPI.\n", stderr);
    SyExit(1);
  }

  UNIX_Realtime((Obj)0); /* initialize UNIX_Realtime:time_since_start */
  {
    if (INT_INTOBJ(MPIcomm_size((Obj)0)) <= 1)
#ifdef USE_MPINU
      printf("\nWARNING:  No slave processes; check procgroup file?\n\n");
#else
      printf("\nWARNING:  No slave processes; did you not start ParGAP with "
             "an MPI launcher?\n\n");
#endif
    if (INT_INTOBJ(MPIcomm_rank((Obj)0)) > 0) {
      SyQuiet = !SyQuiet;
      {
        sigset_t fullset;
        sigfillset(&fullset);
        sigdelset(&fullset, SIGINT); /* Let slaves see interrupts */
#if 0
	sigprocmask( SIG_BLOCK, &fullset, NULL );
#endif
        signal(SIGINT, &ParGAPAnswerIntr); /* Slaves ignore interrupts */
      }
    }
  }
}
/* For backward compatibility */
void InitGapmpi(int * argc_ptr, char *** argv_ptr)
{
  InitPargapmpi(argc_ptr, argv_ptr);
}

/* called after MPI_Init() and after GAP system initialization */
void Init_MPIvars(void)
{
  UInt gvar;

  AssGVar(gvar = GVarName("MPI_TAG_UB"), INTOBJ_INT(MPI_TAG_UB));
  MakeReadOnlyGVar(gvar);
  AssGVar(gvar = GVarName("MPI_HOST"), INTOBJ_INT(MPI_HOST));
  MakeReadOnlyGVar(gvar);
  AssGVar(gvar = GVarName("MPI_IO"), INTOBJ_INT(MPI_IO));
  MakeReadOnlyGVar(gvar);
  AssGVar(gvar = GVarName("MPI_COMM_WORLD"), INTOBJ_INT(MPI_COMM_WORLD));
  MakeReadOnlyGVar(gvar);
  AssGVar(gvar = GVarName("MPI_ANY_SOURCE"), INTOBJ_INT(MPI_ANY_SOURCE));
  MakeReadOnlyGVar(gvar);
  AssGVar(gvar = GVarName("MPI_ANY_TAG"), INTOBJ_INT(MPI_ANY_TAG));
  MakeReadOnlyGVar(gvar);
#ifdef USE_MPINU
  AssGVar(gvar = GVarName("MPI_USE_MPINU"), True);
#ifdef MPINU_V2
  AssGVar(gvar = GVarName("MPI_USE_MPINU_V2"), True);
#else
  AssGVar(gvar = GVarName("MPI_USE_MPINU_V2"), False);
#endif
#else
  AssGVar(gvar = GVarName("MPI_USE_MPINU"), False);
#endif
  MakeReadOnlyGVar(gvar);
}

/*F * * * * * * * * * * * * * initialize package * * * * * * * * * * * * * * *
 */

/****************************************************************************
**

*V  GVarFuncs . . . . . . . . . . . . . . . . . . list of functions to export
*/
static StructGVarFunc GVarFuncs[] = {

  { "UNIX_MakeString", 1, "len", UNIX_MakeString,
    "src/gapmpi.c:UNIX_MakeString" },
  { "UNIX_Chdir", 1, "string", UNIX_Chdir, "src/gapmpi.c:UNIX_Chdir" },
  { "UNIX_FflushStdout", 0, "", UNIX_FflushStdout,
    "src/gapmpi.c:UNIX_FflushStdout" },
  { "UNIX_Catch", 2, "func,arg2", UNIX_Catch, "src/gapmpi.c:UNIX_Catch" },
  { "UNIX_Throw", 0, "", UNIX_Throw, "src/gapmpi.c:UNIX_Throw" },
  { "UNIX_Getpid", 0, "", UNIX_Getpid, "src/gapmpi.c:UNIX_Getpid" },
  { "UNIX_Hostname", 0, "", UNIX_Hostname, "src/gapmpi.c:UNIX_Hostname" },
  { "UNIX_Alarm", 1, "seconds", UNIX_Alarm, "src/gapmpi.c:UNIX_Alarm" },
  { "UNIX_Realtime", 0, "", UNIX_Realtime, "src/gapmpi.c:UNIX_Realtime" },
  { "UNIX_Nice", 1, "priority", UNIX_Nice, "src/gapmpi.c:UNIX_Nice" },
  { "UNIX_LimitRss", 1, "bytes_of_ram", UNIX_LimitRss,
    "src/gapmpi.c:UNIX_LimitRss" },

  { "MPI_Init", 0, "", MPIinit, "src/gapmpi.c:MPI_Init" },
  { "MPI_Initialized", 0, "", MPIinitialized,
    "src/gapmpi.c:MPI_Initialized" },
  { "MPI_Finalize", 0, "", MPIfinalize, "src/gapmpi.c:MPI_Finalize" },
  { "MPI_Comm_rank", 0, "", MPIcomm_rank, "src/gapmpi.c:MPI_Comm_rank" },
  { "MPI_Get_count", 0, "", MPIget_count, "src/gapmpi.c:MPI_Get_count" },
  { "MPI_Get_source", 0, "", MPIget_source, "src/gapmpi.c:MPI_Get_source" },
  { "MPI_Get_tag", 0, "", MPIget_tag, "src/gapmpi.c:MPI_Get_tag" },
  { "MPI_Comm_size", 0, "", MPIcomm_size, "src/gapmpi.c:MPI_Comm_size" },
  { "MPI_World_size", 0, "", MPIworld_size, "src/gapmpi.c:MPI_World_size" },
  { "MPI_Error_string", 1, "errorcode", MPIerror_string,
    "src/gapmpi.c:MPI_Error_string" },
  { "MPI_Get_processor_name", 0, "", MPIget_processor_name,
    "src/gapmpi.c:MPI_Get_processor_name" },
  { "MPI_Attr_get", 1, "keyval", MPIattr_get, "src/gapmpi.c:MPI_Attr_get" },
  { "MPI_Abort", 1, "errorcode", MPIabort, "src/gapmpi.c:MPI_Abort" },
  { "MPI_Send", -1, "args", MPIsend, "src/gapmpi.c:MPI_Send" },
  { "MPI_Recv", -1, "args", MPIrecv, "src/gapmpi.c:MPI_Recv" },
  { "MPI_Probe", -1, "args", MPIprobe, "src/gapmpi.c:MPI_Probe" },
  { "MPI_Iprobe", -1, "args", MPIiprobe, "src/gapmpi.c:MPI_Iprobe" },

  { 0 }

};


/****************************************************************************
**

*F  InitKernel( <module> )  . . . . . . . . initialise kernel data structures
*/
static Int InitKernel(StructInitInfo * module)
{
  /* init filters and functions                                          */
  InitHdlrFuncsFromTable(GVarFuncs);

  /* return success                                                      */
  return 0;
}


/****************************************************************************
**
*F  InitLibrary( <module> ) . . . . . . .  initialise library data structures
*/
static Int InitLibrary(StructInitInfo * module)
{
  /* init filters and functions                                          */
  if (MPIinitialized((Obj)0) == True) {
    InitGVarFuncsFromTable(GVarFuncs);
    Init_MPIvars();
  }

  /* return success                                                      */
  return 0;
}


/****************************************************************************
**
*F  InitInfoPargapmpi() . . . . . . . . . . . . . . . table of init functions
*/
static StructInitInfo module = {
  .type = MODULE_BUILTIN,
  .name = "gapmpi",
  .initKernel = InitKernel,
  .initLibrary = InitLibrary,
};

StructInitInfo * InitInfoGapmpi(void) /* For backward compatibility */
{
  return &module;
}
StructInitInfo * InitInfoPargapmpi(void)
{
  return &module;
}


/****************************************************************************
**

*E  gapmpi.c  . . . . . . . . . . . . . . . . . . . . . . . . . . ends here
*/

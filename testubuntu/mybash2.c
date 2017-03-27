#define _GNU_SOURCE
#include <sys/types.h>
#include <sys/wait.h>
#include <stdio.h>
#include <sched.h>
#include<stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <errno.h>
#define STACK_SIZE (1024 * 1024)

extern int errno ;

static char child_stack[STACK_SIZE];
char**  child_args;
char* machinename = "testmachine";

int child_main(void* args) { 
  sethostname(machinename, strlen(machinename));
  
  execv(child_args[0], child_args);
  return 1;
}

int main(int argc ,char * argv[]) { 
  child_args = (char* *)malloc((argc+2) * sizeof(char*));
  child_args[0]  = "/bin/bash";
  child_args[1] = NULL;

  if (argc > 1) {
     machinename = argv[1];
     for (int i = 2; i < argc ; i++) {
          child_args[i-1] = argv[i];
     }
     child_args[argc-1] = NULL;
  }

  int child_pid = clone(child_main, child_stack+STACK_SIZE,
   CLONE_NEWNS |CLONE_NEWPID | CLONE_NEWIPC | CLONE_NEWUTS | SIGCHLD, NULL); 
  waitpid(child_pid, NULL, 0);
  return 0;
}

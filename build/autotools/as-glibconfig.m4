dnl
dnl Test program for basic POSIX threads functionality
dnl
m4_define([glib_thread_test],[
#include <pthread.h> 
int check_me = 0;
void* func(void* data) {check_me = 42; return &check_me;}
int main()
 { pthread_t t; 
   void *ret;
   pthread_create (&t, $1, func, 0);
   pthread_join (t, &ret);
   return (check_me != 42 || ret != &check_me);
}])

AC_DEFUN([AS_GLIBCONFIG],
[

m4_define([glib_major_version], [2])
m4_define([glib_minor_version], [30])
m4_define([glib_micro_version], [2])
m4_define([glib_interface_age], [0]) 
m4_define([glib_binary_age],
          [m4_eval(100 * glib_minor_version + glib_micro_version)])
m4_define([glib_version],
          [glib_major_version.glib_minor_version.glib_micro_version])

GLIB_MAJOR_VERSION=glib_major_version
GLIB_MINOR_VERSION=glib_minor_version
GLIB_MICRO_VERSION=glib_micro_version
GLIB_INTERFACE_AGE=glib_interface_age
GLIB_BINARY_AGE=glib_binary_age
GLIB_VERSION=glib_version

AC_SUBST(GLIB_MAJOR_VERSION)
AC_SUBST(GLIB_MINOR_VERSION)
AC_SUBST(GLIB_MICRO_VERSION)
AC_SUBST(GLIB_VERSION)
AC_SUBST(GLIB_INTERFACE_AGE)
AC_SUBST(GLIB_BINARY_AGE)

AC_DEFINE(GLIB_INTERFACE_AGE, [glib_interface_age],
          [Define to the GLIB interface age])
AC_DEFINE(GLIB_BINARY_AGE, [glib_binary_age],
          [Define to the GLIB binary age])

dnl Let's use the system printf unconditionally
enable_included_printf=no
AC_DEFINE(HAVE_GOOD_PRINTF,1,[define to use system printf])

dnl No support for static window libraries 
glib_win32_static_compilation=no

dnl that's the defaults in glib's configure (which provides a --with-threads
dnl option we don't expose here)
want_threads=yes

AC_CANONICAL_HOST

AC_MSG_CHECKING([for Win32])
LIB_EXE_MACHINE_FLAG=X86
case "$host" in
  *-*-mingw*)
    glib_native_win32=yes
    glib_pid_type='void *'
    glib_cv_stack_grows=no
    # Unfortunately the mingw implementations of C99-style snprintf and vsnprintf
    # don't seem to be quite good enough, at least not in mingw-runtime-3.14.
    # (Sorry, I don't know exactly what is the problem, but it is related to
    # floating point formatting and decimal point vs. comma.)
    # The simple tests in AC_FUNC_VSNPRINTF_C99 and AC_FUNC_SNPRINTF_C99 aren't
    # rigorous enough to notice, though.
    # So preset the autoconf cache variables.
    ac_cv_func_vsnprintf_c99=no
    ac_cv_func_snprintf_c99=no
    case "$host" in
    x86_64-*-*)
      LIB_EXE_MACHINE_FLAG=X64
      ;;
    esac
    ;;
  *)
    glib_native_win32=no
    glib_pid_type=int
    ;;
esac
case $host in
  *-*-linux*)
    glib_os_linux=yes
    ;;
esac

AC_MSG_RESULT([$glib_native_win32])

AC_SUBST(LIB_EXE_MACHINE_FLAG)

glib_have_carbon=no
AC_MSG_CHECKING([for Mac OS X Carbon support])
AC_TRY_CPP([
#include <Carbon/Carbon.h>
#include <CoreServices/CoreServices.h>
], glib_have_carbon=yes)

AC_MSG_RESULT([$glib_have_carbon])

AC_CHECK_HEADERS([limits.h float.h values.h alloca.h sys/poll.h])
AC_CHECK_FUNCS(atexit on_exit memmove)

AC_CHECK_SIZEOF(char)
AC_CHECK_SIZEOF(short)
AC_CHECK_SIZEOF(long)
AC_CHECK_SIZEOF(int)
AC_CHECK_SIZEOF(void *)
AC_CHECK_SIZEOF(long long)
AC_CHECK_SIZEOF(__int64)

if test x$ac_cv_sizeof_long = x8 || test x$ac_cv_sizeof_long_long = x8 || test x$ac_cv_sizeof___int64 = x8 ; then
  :
else
  AC_MSG_ERROR([
*** GLib requires a 64 bit type. You might want to consider
*** using the GNU C compiler.
])
fi

if test x$glib_native_win32 != xyes && test x$ac_cv_sizeof_long_long = x8; then
	# long long is a 64 bit integer.
	AC_MSG_CHECKING(for format to printf and scanf a guint64)
	AC_CACHE_VAL(glib_cv_long_long_format,[
		for format in ll q I64; do
		  AC_TRY_RUN([#include <stdio.h>  
			int main()
			{
			  long long b, a = -0x3AFAFAFAFAFAFAFALL;
			  char buffer[1000];
			  sprintf (buffer, "%${format}u", a);
  			  sscanf (buffer, "%${format}u", &b);
			  exit (b!=a);
			}
			],
			[glib_cv_long_long_format=${format}
			break],
			[],[:])
		done])
	if test -n "$glib_cv_long_long_format"; then
	  AC_MSG_RESULT(%${glib_cv_long_long_format}u)
	  AC_DEFINE(HAVE_LONG_LONG_FORMAT,1,[define if system printf can print long long])
	  if test x"$glib_cv_long_long_format" = xI64; then
	    AC_DEFINE(HAVE_INT64_AND_I64,1,[define to support printing 64-bit integers with format I64])
	  fi
        else
	  AC_MSG_RESULT(none)
        fi
elif test x$ac_cv_sizeof___int64 = x8; then
	# __int64 is a 64 bit integer.
	AC_MSG_CHECKING(for format to printf and scanf a guint64)
	# We know this is MSVCRT.DLL, and what the formats are
	glib_cv_long_long_format=I64
	AC_MSG_RESULT(%${glib_cv_long_long_format}u)
        AC_DEFINE(HAVE_LONG_LONG_FORMAT,1,[define if system printf can print long long])
	AC_DEFINE(HAVE_INT64_AND_I64,1,[define to support printing 64-bit integers with format I64])
fi

# check additional type sizes
AC_CHECK_SIZEOF(size_t)

dnl Try to figure out whether gsize, gssize should be long or int
AC_MSG_CHECKING([for the appropriate definition for size_t])

case $ac_cv_sizeof_size_t in
  $ac_cv_sizeof_short) 
      glib_size_type=short
      ;;
  $ac_cv_sizeof_int) 
      glib_size_type=int
      ;;
  $ac_cv_sizeof_long) 
      glib_size_type=long
      ;;
  $ac_cv_sizeof_long_long)
      glib_size_type='long long'
      ;;
  $ac_cv_sizeof__int64)
      glib_size_type='__int64'
      ;;
  *)  AC_MSG_ERROR([No type matching size_t in size])
      ;;
esac

dnl If int/long are the same size, we see which one produces
dnl warnings when used in the location as size_t. (This matters
dnl on AIX with xlc)
dnl
if test $ac_cv_sizeof_size_t = $ac_cv_sizeof_int &&
   test $ac_cv_sizeof_size_t = $ac_cv_sizeof_long ; then
  GLIB_CHECK_COMPILE_WARNINGS([AC_LANG_SOURCE([[
#if defined(_AIX) && !defined(__GNUC__)
#pragma options langlvl=stdc89
#endif
#include <stddef.h> 
int main ()
{
  size_t s = 1;
  unsigned int *size_int = &s;
  return (int)*size_int;
}
    ]])],glib_size_type=int,
      [GLIB_CHECK_COMPILE_WARNINGS([AC_LANG_SOURCE([[
#if defined(_AIX) && !defined(__GNUC__)
#pragma options langlvl=stdc89
#endif
#include <stddef.h> 
int main ()
{
   size_t s = 1;
   unsigned long *size_long = &s;
   return (int)*size_long;
}
        ]])],glib_size_type=long)])
fi

AC_MSG_RESULT(unsigned $glib_size_type)

# Check for some functions
AC_CHECK_FUNCS(lstat strerror strsignal memmove vsnprintf stpcpy strcasecmp strncasecmp poll getcwd vasprintf setenv unsetenv getc_unlocked readlink symlink fdwalk memmem)
AC_CHECK_FUNCS(chown lchmod lchown fchmod fchown link utimes getgrgid getpwuid)
AC_CHECK_FUNCS(getmntent_r setmntent endmntent hasmntopt getfsstat getvfsstat)
# Check for high-resolution sleep functions
AC_CHECK_FUNCS(splice)

# Check if bcopy can be used for overlapping copies, if memmove isn't found.
# The check is borrowed from the PERL Configure script.
if test "$ac_cv_func_memmove" != "yes"; then
  AC_CACHE_CHECK(whether bcopy can handle overlapping copies,
    glib_cv_working_bcopy,[AC_TRY_RUN([
      int main() {
        char buf[128], abc[128], *b;
        int len, off, align;
        bcopy("abcdefghijklmnopqrstuvwxyz0123456789", abc, 36);
        for (align = 7; align >= 0; align--) {
          for (len = 36; len; len--) {
            b = buf+align; bcopy(abc, b, len);
            for (off = 1; off <= len; off++) {
              bcopy(b, b+off, len); bcopy(b+off, b, len);
                if (bcmp(b, abc, len)) return(1);
            }
          }
        }
        return(0);
      }],glib_cv_working_bcopy=yes,glib_cv_working_bcopy=no)])

  GLIB_ASSERT_SET(glib_cv_working_bcopy)
  if test "$glib_cv_working_bcopy" = "yes"; then
    AC_DEFINE(HAVE_WORKING_BCOPY,1,[Have a working bcopy])
  fi
fi

# Check for sys_errlist
AC_MSG_CHECKING(for sys_errlist)
AC_TRY_LINK(, [
extern char *sys_errlist[];
extern int sys_nerr;
sys_errlist[sys_nerr-1][0] = 0;
], glib_ok=yes, glib_ok=no)
AC_MSG_RESULT($glib_ok)
if test "$glib_ok" = "no"; then
    AC_DEFINE(NO_SYS_ERRLIST,1,[global 'sys_errlist' not found])
fi


dnl va_copy checks
dnl we currently check for all three va_copy possibilities, so we get
dnl all results in config.log for bug reports.
AC_CACHE_CHECK([for an implementation of va_copy()],glib_cv_va_copy,[
	AC_LINK_IFELSE([AC_LANG_SOURCE([[#include <stdarg.h>
#include <stdlib.h>
	void f (int i, ...) {
	va_list args1, args2;
	va_start (args1, i);
	va_copy (args2, args1);
	if (va_arg (args2, int) != 42 || va_arg (args1, int) != 42)
	  exit (1);
	va_end (args1); va_end (args2);
	}
	int main() {
	  f (0, 42);
	  return 0;
	}]])],
	[glib_cv_va_copy=yes],
	[glib_cv_va_copy=no])
])
AC_CACHE_CHECK([for an implementation of __va_copy()],glib_cv___va_copy,[
	AC_LINK_IFELSE([AC_LANG_SOURCE([[#include <stdarg.h>
#include <stdlib.h>
	void f (int i, ...) {
	va_list args1, args2;
	va_start (args1, i);
	__va_copy (args2, args1);
	if (va_arg (args2, int) != 42 || va_arg (args1, int) != 42)
	  exit (1);
	va_end (args1); va_end (args2);
	}
	int main() {
	  f (0, 42);
	  return 0;
	}]])],
	[glib_cv___va_copy=yes],
	[glib_cv___va_copy=no])
])

if test "x$glib_cv_va_copy" = "xyes"; then
  g_va_copy_func=va_copy
else if test "x$glib_cv___va_copy" = "xyes"; then
  g_va_copy_func=__va_copy
fi
fi

if test -n "$g_va_copy_func"; then
  AC_DEFINE_UNQUOTED(G_VA_COPY,$g_va_copy_func,[A 'va_copy' style function])
fi

AC_CACHE_CHECK([whether va_lists can be copied by value],glib_cv_va_val_copy,[
	AC_TRY_RUN([#include <stdarg.h>
#include <stdlib.h> 
	void f (int i, ...) {
	va_list args1, args2;
	va_start (args1, i);
	args2 = args1;
	if (va_arg (args2, int) != 42 || va_arg (args1, int) != 42)
	  exit (1);
	va_end (args1); va_end (args2);
	}
	int main() {
	  f (0, 42);
	  return 0;
	}],
	[glib_cv_va_val_copy=yes],
	[glib_cv_va_val_copy=no],
	[glib_cv_va_val_copy=yes])
])

if test "x$glib_cv_va_val_copy" = "xno"; then
  AC_DEFINE(G_VA_COPY_AS_ARRAY,1, ['va_lists' cannot be copies as values])
fi

dnl ***********************
dnl *** g_module checks ***
dnl ***********************
G_MODULE_LIBS=
G_MODULE_LIBS_EXTRA=
G_MODULE_PLUGIN_LIBS=
if test x"$glib_native_win32" = xyes; then
  dnl No use for this on Win32
  G_MODULE_LDFLAGS=
else
  export SED
  G_MODULE_LDFLAGS=`(./libtool --config; echo eval echo \\$export_dynamic_flag_spec) | sh`
fi
dnl G_MODULE_IMPL= don't reset, so cmd-line can override
G_MODULE_NEED_USCORE=0
G_MODULE_BROKEN_RTLD_GLOBAL=0
G_MODULE_HAVE_DLERROR=0
dnl *** force native WIN32 shared lib loader 
if test -z "$G_MODULE_IMPL"; then
  case "$host" in
  *-*-mingw*|*-*-cygwin*) G_MODULE_IMPL=G_MODULE_IMPL_WIN32 ;;
  esac
fi
dnl *** force native AIX library loader
dnl *** dlopen() filepath must be of the form /path/libname.a(libname.so)
if test -z "$G_MODULE_IMPL"; then
  case "$host" in
  *-*-aix*) G_MODULE_IMPL=G_MODULE_IMPL_AR ;;
  esac
fi
dnl *** dlopen() and dlsym() in system libraries
if test -z "$G_MODULE_IMPL"; then
	AC_CHECK_FUNC(dlopen,
		      [AC_CHECK_FUNC(dlsym,
			             [G_MODULE_IMPL=G_MODULE_IMPL_DL],[])],
		      [])
fi
dnl *** load_image (BeOS)
if test -z "$G_MODULE_IMPL" && test "x$glib_native_beos" = "xyes"; then
  AC_CHECK_LIB(root, load_image,
      [G_MODULE_LIBS="-lbe -lroot -lglib-2.0 "
      G_MODULE_LIBS_EXTRA="-L\$(top_builddir_full)/.libs"
      G_MODULE_PLUGIN_LIBS="-L\$(top_builddir_full)/gmodule/.libs -lgmodule"
      G_MODULE_IMPL=G_MODULE_IMPL_BEOS],
      [])
fi   
dnl *** NSLinkModule (dyld) in system libraries (Darwin)
if test -z "$G_MODULE_IMPL"; then
 	AC_CHECK_FUNC(NSLinkModule,
		      [G_MODULE_IMPL=G_MODULE_IMPL_DYLD
		       G_MODULE_NEED_USCORE=1],
		      [])
fi
dnl *** dlopen() and dlsym() in libdl
if test -z "$G_MODULE_IMPL"; then
	AC_CHECK_LIB(dl, dlopen,
		     [AC_CHECK_LIB(dl, dlsym,
			           [G_MODULE_LIBS=-ldl
		                   G_MODULE_IMPL=G_MODULE_IMPL_DL],[])],
		     [])
fi
dnl *** shl_load() in libdld (HP-UX)
if test -z "$G_MODULE_IMPL"; then
	AC_CHECK_LIB(dld, shl_load,
		[G_MODULE_LIBS=-ldld
		G_MODULE_IMPL=G_MODULE_IMPL_DLD],
		[])
fi
dnl *** additional checks for G_MODULE_IMPL_DL
if test "$G_MODULE_IMPL" = "G_MODULE_IMPL_DL"; then
	LIBS_orig="$LIBS"
	LDFLAGS_orig="$LDFLAGS"
	LIBS="$G_MODULE_LIBS $LIBS"
	LDFLAGS="$LDFLAGS $G_MODULE_LDFLAGS"
dnl *** check for OSF1/5.0 RTLD_GLOBAL brokenness
	echo "void glib_plugin_test(void) { }" > plugin.c
	${SHELL} ./libtool --mode=compile ${CC} -shared \
		-export-dynamic -o plugin.o plugin.c 2>&1 >/dev/null
	AC_CACHE_CHECK([for RTLD_GLOBAL brokenness],
		glib_cv_rtldglobal_broken,[
		AC_TRY_RUN([
#include <dlfcn.h>
#ifndef RTLD_GLOBAL
#  define RTLD_GLOBAL 0
#endif
#ifndef RTLD_LAZY
#  define RTLD_LAZY 0
#endif
int glib_plugin_test;
int main () {
    void *handle, *global, *local;
    global = &glib_plugin_test;
    handle = dlopen ("./.libs/plugin.o", RTLD_GLOBAL | RTLD_LAZY);
    if (!handle) return 0;
    local = dlsym (handle, "glib_plugin_test");
    return global == local;
}                       ],
			[glib_cv_rtldglobal_broken=no],
			[glib_cv_rtldglobal_broken=yes],
			[glib_cv_rtldglobal_broken=no])
		rm -f plugin.c plugin.o plugin.lo .libs/plugin.o
		rmdir .libs 2>/dev/null
	])
	if test "x$glib_cv_rtldglobal_broken" = "xyes"; then
  		G_MODULE_BROKEN_RTLD_GLOBAL=1
	else
  		G_MODULE_BROKEN_RTLD_GLOBAL=0
	fi
dnl *** check whether we need preceeding underscores
	AC_CACHE_CHECK([for preceeding underscore in symbols],
		glib_cv_uscore,[
		AC_TRY_RUN([#include <dlfcn.h>
                int glib_underscore_test (void) { return 42; }
		int main() {
		  void *f1 = (void*)0, *f2 = (void*)0, *handle;
		  handle = dlopen ((void*)0, 0);
		  if (handle) {
		    f1 = dlsym (handle, "glib_underscore_test");
		    f2 = dlsym (handle, "_glib_underscore_test");
		  } return (!f2 || f1);
		}],
			[glib_cv_uscore=yes],
			[glib_cv_uscore=no],
			[])
		rm -f plugin.c plugin.$ac_objext plugin.lo
	])
        GLIB_ASSERT_SET(glib_cv_uscore)
	if test "x$glib_cv_uscore" = "xyes"; then
  		G_MODULE_NEED_USCORE=1
	else
  		G_MODULE_NEED_USCORE=0
	fi

	LDFLAGS="$LDFLAGS_orig"
dnl *** check for having dlerror()
	AC_CHECK_FUNC(dlerror,
		[G_MODULE_HAVE_DLERROR=1],
		[G_MODULE_HAVE_DLERROR=0])
	LIBS="$LIBS_orig"
fi
dnl *** done, have we got an implementation?
if test -z "$G_MODULE_IMPL"; then
	G_MODULE_IMPL=0
        G_MODULE_SUPPORTED=false
else
        G_MODULE_SUPPORTED=true
fi

AC_MSG_CHECKING(for the suffix of module shared libraries)
export SED
shrext_cmds=`./libtool --config | grep '^shrext_cmds='`
eval $shrext_cmds
module=yes eval std_shrext=$shrext_cmds
# chop the initial dot
glib_gmodule_suffix=`echo $std_shrext | sed 's/^\.//'`
AC_MSG_RESULT(.$glib_gmodule_suffix)
# any reason it may fail?
if test "x$glib_gmodule_suffix" = x; then
	AC_MSG_ERROR(Cannot determine shared library suffix from libtool)
fi
 
AC_SUBST(G_MODULE_SUPPORTED)
AC_SUBST(G_MODULE_IMPL)
AC_SUBST(G_MODULE_LIBS)
AC_SUBST(G_MODULE_LIBS_EXTRA)
AC_SUBST(G_MODULE_PLUGIN_LIBS)
AC_SUBST(G_MODULE_LDFLAGS)
AC_SUBST(G_MODULE_HAVE_DLERROR)
AC_SUBST(G_MODULE_BROKEN_RTLD_GLOBAL)
AC_SUBST(G_MODULE_NEED_USCORE)
AC_SUBST(GLIB_DEBUG_FLAGS)

dnl AC_C_INLINE is useless to us since it bails out too early, we need to
dnl truely know which ones of `inline', `__inline' and `__inline__' are
dnl actually supported.
AC_CACHE_CHECK([for __inline],glib_cv_has__inline,[
        AC_COMPILE_IFELSE([AC_LANG_SOURCE([[
	__inline int foo () { return 0; }
	int main () { return foo (); }
	]])],
	glib_cv_has__inline=yes
        ,
	glib_cv_has__inline=no
        ,)
])
case x$glib_cv_has__inline in
xyes) AC_DEFINE(G_HAVE___INLINE,1,[Have __inline keyword])
esac
AC_CACHE_CHECK([for __inline__],glib_cv_has__inline__,[
        AC_COMPILE_IFELSE([AC_LANG_SOURCE([[
	__inline__ int foo () { return 0; }
	int main () { return foo (); }
	]])],
	glib_cv_has__inline__=yes
        ,
	glib_cv_has__inline__=no
        ,)
])
case x$glib_cv_has__inline__ in
xyes) AC_DEFINE(G_HAVE___INLINE__,1,[Have __inline__ keyword])
esac
AC_CACHE_CHECK([for inline], glib_cv_hasinline,[
        AC_COMPILE_IFELSE([AC_LANG_SOURCE([[
	#undef inline
	inline int foo () { return 0; }
	int main () { return foo (); }
	]])],
	glib_cv_hasinline=yes
        ,
	glib_cv_hasinline=no
        ,)
])
case x$glib_cv_hasinline in
xyes) AC_DEFINE(G_HAVE_INLINE,1,[Have inline keyword])
esac

# if we can use inline functions in headers
AC_MSG_CHECKING(if inline functions in headers work)
AC_LINK_IFELSE([AC_LANG_SOURCE([[
#if defined (G_HAVE_INLINE) && defined (__GNUC__) && defined (__STRICT_ANSI__)
#  undef inline
#  define inline __inline__
#elif !defined (G_HAVE_INLINE)
#  undef inline
#  if defined (G_HAVE___INLINE__)
#    define inline __inline__
#  elif defined (G_HAVE___INLINE)
#    define inline __inline
#  endif
#endif

int glib_test_func2 (int);

static inline int
glib_test_func1 (void) {
  return glib_test_func2 (1);
}

int
main (void) {
  int i = 1;
}]])],[g_can_inline=yes],[g_can_inline=no])
AC_MSG_RESULT($g_can_inline)

# check for flavours of varargs macros
AC_MSG_CHECKING(for ISO C99 varargs macros in C)
AC_TRY_COMPILE([],[
int a(int p1, int p2, int p3);
#define call_a(...) a(1,__VA_ARGS__)
call_a(2,3);
],g_have_iso_c_varargs=yes,g_have_iso_c_varargs=no)
AC_MSG_RESULT($g_have_iso_c_varargs)

AC_MSG_CHECKING(for ISO C99 varargs macros in C++)
if test "$CXX" = ""; then
dnl No C++ compiler
  g_have_iso_cxx_varargs=no
else
  AC_LANG_CPLUSPLUS
  AC_TRY_COMPILE([],[
int a(int p1, int p2, int p3);
#define call_a(...) a(1,__VA_ARGS__)
call_a(2,3);
],g_have_iso_cxx_varargs=yes,g_have_iso_cxx_varargs=no)
  AC_LANG_C
fi
AC_MSG_RESULT($g_have_iso_cxx_varargs)

AC_MSG_CHECKING(for GNUC varargs macros)
AC_TRY_COMPILE([],[
int a(int p1, int p2, int p3);
#define call_a(params...) a(1,params)
call_a(2,3);
],g_have_gnuc_varargs=yes,g_have_gnuc_varargs=no)
AC_MSG_RESULT($g_have_gnuc_varargs)

AC_MSG_CHECKING([for EILSEQ])
AC_TRY_COMPILE([
#include <errno.h>
],
[
int error = EILSEQ;
], have_eilseq=yes, have_eilseq=no);
AC_MSG_RESULT($have_eilseq)

# check for GNUC visibility support
AC_MSG_CHECKING(for GNUC visibility attribute)
GLIB_CHECK_COMPILE_WARNINGS([AC_LANG_SOURCE([[
void
__attribute__ ((visibility ("hidden")))
     f_hidden (void)
{
}
void
__attribute__ ((visibility ("internal")))
     f_internal (void)
{
}
void
__attribute__ ((visibility ("protected")))
     f_protected (void)
{
}
void
__attribute__ ((visibility ("default")))
     f_default (void)
{
}
int main (int argc, char **argv)
{
	f_hidden();
	f_internal();
	f_protected();
	f_default();
	return 0;
}
]])],g_have_gnuc_visibility=yes,g_have_gnuc_visibility=no)
AC_MSG_RESULT($g_have_gnuc_visibility)

# check for bytesex stuff
AC_C_BIGENDIAN
if test x$ac_cv_c_bigendian = xuniversal ; then
AC_TRY_COMPILE([#include <endian.h>], [#if __BYTE_ORDER == __BIG_ENDIAN
#else
#error Not a big endian. 
#endif],
    ac_cv_c_bigendian=yes
    ,AC_TRY_COMPILE([#include <endian.h>], [#if __BYTE_ORDER == __LITTLE_ENDIAN
#else
#error Not a little endian. 
#endif],
    ac_cv_c_bigendian=no
    ,AC_MSG_WARN([Could not determine endianness.])))
fi


# check for header files
AC_CHECK_HEADERS([dirent.h float.h limits.h pwd.h grp.h sys/param.h sys/poll.h sys/resource.h])
AC_CHECK_HEADERS([sys/time.h sys/times.h sys/wait.h unistd.h values.h])
AC_CHECK_HEADERS([sys/select.h sys/types.h stdint.h inttypes.h sched.h malloc.h])
AC_CHECK_HEADERS([sys/vfs.h sys/vmount.h sys/statfs.h sys/statvfs.h])
AC_CHECK_HEADERS([mntent.h sys/mnttab.h sys/vfstab.h sys/mntctl.h fstab.h])
AC_CHECK_HEADERS([sys/uio.h sys/mkdev.h])
AC_CHECK_HEADERS([linux/magic.h])

AC_CHECK_HEADERS([sys/mount.h sys/sysctl.h], [], [],
[#if HAVE_SYS_PARAM_H
 #include <sys/param.h>
 #endif
])

# check for structure fields
AC_CHECK_MEMBERS([struct stat.st_mtimensec, struct stat.st_mtim.tv_nsec, struct stat.st_atimensec, struct stat.st_atim.tv_nsec, struct stat.st_ctimensec, struct stat.st_ctim.tv_nsec])
AC_CHECK_MEMBERS([struct stat.st_blksize, struct stat.st_blocks, struct statfs.f_fstypename, struct statfs.f_bavail],,, [#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#ifdef HAVE_SYS_STATFS_H
#include <sys/statfs.h>
#endif
#ifdef HAVE_SYS_PARAM_H
#include <sys/param.h>
#endif
#ifdef HAVE_SYS_MOUNT_H
#include <sys/mount.h>
#endif])
# struct statvfs.f_basetype is available on Solaris but not for Linux. 
AC_CHECK_MEMBERS([struct statvfs.f_basetype],,, [#include <sys/statvfs.h>])
AC_CHECK_MEMBERS([struct statvfs.f_fstypename],,, [#include <sys/statvfs.h>])
AC_CHECK_MEMBERS([struct tm.tm_gmtoff, struct tm.__tm_gmtoff],,,[#include <time.h>])

dnl error and warning message
dnl *************************

THREAD_NO_IMPLEMENTATION="You do not have any known thread system on your
                computer. GLib will not have a default thread implementation."

FLAG_DOES_NOT_WORK="I can't find the MACRO to enable thread safety on your
                platform (normally it's "_REENTRANT"). I'll not use any flag on
                compilation now, but then your programs might not work.
                Please provide information on how it is done on your system."

LIBS_NOT_FOUND_1="I can't find the libraries for the thread implementation
		"

LIBS_NOT_FOUND_2=". Please choose another thread implementation or
		provide information on your thread implementation.
		You can also run 'configure --disable-threads' 
		to compile without thread support."

FUNC_NO_GETPWUID_R="the 'g_get_(user_name|real_name|home_dir|tmp_dir)'
		functions will not be MT-safe during their first call because
		there is no working 'getpwuid_r' on your system."

FUNC_NO_LOCALTIME_R="the 'g_date_set_time' function will not be MT-safe
		because there is no 'localtime_r' on your system."

POSIX_NO_YIELD="I can not find a yield functions for your platform. A rather
		crude surrogate will be used. If you happen to know a 
		yield function for your system, please inform the GLib 
		developers."

POSIX_NO_PRIORITIES="I can not find the minimal and maximal priorities for 
		threads on your system. Thus threads can only have the default 
		priority. If you happen to know these main/max
		priorities, please inform the GLib developers."

AIX_COMPILE_INFO="AIX's C compiler needs to be called by a different name, when
		linking threaded applications. As GLib cannot do that 
		automatically, you will get an linkg error everytime you are 
		not using the right compiler. In that case you have to relink 
		with the right compiler. Ususally just '_r' is appended 
		to the compiler name."

dnl determination of thread implementation
dnl ***************************************

# have_threads=no   means no thread support
# have_threads=none means no default thread implementation

have_threads=no
if test "x$want_threads" = xyes || test "x$want_threads" = xposix \
				|| test "x$want_threads" = xdce; then
	# -D_POSIX4_DRAFT_SOURCE -D_POSIX4A_DRAFT10_SOURCE is for DG/UX
	# -U_OSF_SOURCE is for Digital UNIX 4.0d
	GTHREAD_COMPILE_IMPL_DEFINES="-D_POSIX4_DRAFT_SOURCE -D_POSIX4A_DRAFT10_SOURCE -U_OSF_SOURCE"
	glib_save_CPPFLAGS="$CPPFLAGS"
	CPPFLAGS="$CPPFLAGS $GTHREAD_COMPILE_IMPL_DEFINES"
        if test "x$have_threads" = xno; then
                AC_TRY_COMPILE([#include <pthread.h>],
			[pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;],
			have_threads=posix)
        fi
        if test "x$have_threads" = xno; then
                AC_TRY_COMPILE([#include <pthread.h>],
			[pthread_mutex_t m; 
                         pthread_mutex_init (&m, pthread_mutexattr_default);],
			have_threads=dce)
        fi
	# Tru64Unix requires -pthread to find pthread.h. See #103020
	CPPFLAGS="$CPPFLAGS -pthread"
	if test "x$have_threads" = xno; then
	AC_TRY_COMPILE([#include <pthread.h>],
		       [pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;],
		       have_threads=posix)
        fi
	CPPFLAGS="$glib_save_CPPFLAGS"
fi
if test "x$want_threads" = xyes || test "x$want_threads" = xwin32; then
       	case $host in
               	*-*-mingw*)
		have_threads=win32
		;;
	esac
fi
if test "x$want_threads" = xnone; then
	have_threads=none
fi

AC_MSG_CHECKING(for thread implementation)

if test "x$have_threads" = xno && test "x$want_threads" != xno; then
	AC_MSG_RESULT(none available)
        AC_MSG_WARN($THREAD_NO_IMPLEMENTATION)
else
	AC_MSG_RESULT($have_threads)
fi


dnl determination of G_THREAD_CFLAGS
dnl ********************************

G_THREAD_LIBS=
G_THREAD_LIBS_EXTRA=
G_THREAD_CFLAGS=

dnl
dnl Test program for sched_get_priority_min()
dnl
m4_define([glib_sched_priority_test],[
#include <sched.h>
#include <errno.h>
int main() {
    errno = 0;
    return sched_get_priority_min(SCHED_OTHER)==-1
 	   && errno != 0;
}])

if test x"$have_threads" != xno; then

  if test x"$have_threads" = xposix; then
    # First we test for posix, whether -pthread or -pthreads do the trick as 
    # both CPPFLAG and LIBS. 
    # One of them does for most gcc versions and some other platforms/compilers
    # too and could be considered as the canonical way to go. 
    case $host in
      *-*-cygwin*|*-*-darwin*)
         # skip cygwin and darwin -pthread or -pthreads test
         ;;
      *-solaris*)
        # These compiler/linker flags work with both Sun Studio and gcc
	# Sun Studio expands -mt to -D_REENTRANT and -lthread
	# gcc expands -pthreads to -D_REENTRANT -D_PTHREADS -lpthread
        G_THREAD_CFLAGS="-D_REENTRANT -D_PTHREADS"
        G_THREAD_LIBS="-lpthread -lthread"
        ;;
      *)
        for flag in pthread pthreads mt; do
          glib_save_CFLAGS="$CFLAGS"
          CFLAGS="$CFLAGS -$flag"
          AC_TRY_RUN(glib_thread_test(0),
                     glib_flag_works=yes,
                     glib_flag_works=no,
                     [AC_LINK_IFELSE([AC_LANG_SOURCE(glib_thread_test(0))],
                                     glib_flag_works=yes,
                                     glib_flag_works=no)])
          CFLAGS="$glib_save_CFLAGS"
          if test $glib_flag_works = yes ; then
             G_THREAD_CFLAGS=-$flag
	     G_THREAD_LIBS=-$flag
	     break;
          fi
        done
         ;;
    esac 
  fi

  if test x"$G_THREAD_CFLAGS" = x; then

    # The canonical -pthread[s] does not work. Try something different.

    case $host in
	*-aix*)
		if test x"$GCC" = xyes; then
			# GCC 3.0 and above needs -pthread. 
			# Should be coverd by the case above.
			# GCC 2.x and below needs -mthreads
			G_THREAD_CFLAGS="-mthreads"		
			G_THREAD_LIBS=$G_THREAD_CFLAGS
		else 
			# We are probably using the aix compiler. Normaly a 
			# program would have to be compiled with the _r variant
			# of the corresponding compiler, but we as GLib cannot 
			# do that: but the good news is that for compiling the
			# only difference is the added -D_THREAD_SAFE compile 
			# option. This is according to the "C for AIX User's 
			# Guide".
			G_THREAD_CFLAGS="-D_THREAD_SAFE"
		fi
		;;
	*-dg-dgux*)  # DG/UX
		G_THREAD_CFLAGS="-D_REENTRANT -D_POSIX4A_DRAFT10_SOURCE"
		;;
	*-osf*)
		# So we are using dce threads. posix threads are already 
		# catched above.
		G_THREAD_CFLAGS="-threads"
		G_THREAD_LIBS=$G_THREAD_CFLAGS
		;;
	*-sysv5uw7*) # UnixWare 7 
		# We are not using gcc with -pthread. Catched above.
		G_THREAD_CFLAGS="-Kthread"
		G_THREAD_LIBS=$G_THREAD_CFLAGS
		;;
	*-mingw*)
		# No flag needed when using MSVCRT.DLL
		G_THREAD_CFLAGS=""
		;;
	*)
		G_THREAD_CFLAGS="-D_REENTRANT" # good default guess otherwise
		;;
    esac
 
  fi

    # if we are not finding the localtime_r function, then we probably are
    # not using the proper multithread flag

    glib_save_CPPFLAGS="$CPPFLAGS"
    CPPFLAGS="$CPPFLAGS $G_THREAD_CFLAGS"

    # First we test, whether localtime_r is declared in time.h
    # directly. Then we test whether a macro localtime_r exists, in
    # which case localtime_r in the test program is replaced and thus
    # if we still find localtime_r in the output, it is not defined as 
    # a macro.

    AC_EGREP_CPP([[^a-zA-Z1-9_]localtime_r[^a-zA-Z1-9_]], [#include <time.h>], ,
      [AC_EGREP_CPP([[^a-zA-Z1-9_]localtime_r[^a-zA-Z1-9_]], [#include <time.h> 
							   localtime_r(a,b)],
      		   AC_MSG_WARN($FLAG_DOES_NOT_WORK))])

    CPPFLAGS="$glib_save_CPPFLAGS"

    AC_MSG_CHECKING(thread related cflags)
    AC_MSG_RESULT($G_THREAD_CFLAGS)
    CPPFLAGS="$CPPFLAGS $G_THREAD_CFLAGS"
fi

dnl determination of G_THREAD_LIBS
dnl ******************************

mutex_has_default=no
case $have_threads in
        posix|dce)
	  glib_save_CPPFLAGS="$CPPFLAGS"
	  CPPFLAGS="$CPPFLAGS $GTHREAD_COMPILE_IMPL_DEFINES"
          if test x"$G_THREAD_LIBS" = x; then
            case $host in
              *-aix*)
                # We are not using gcc (would have set G_THREAD_LIBS) and thus 
                # probably using the aix compiler.
		AC_MSG_WARN($AIX_COMPILE_INFO)
                ;;
              *)
                G_THREAD_LIBS=error
	        glib_save_LIBS="$LIBS"
	        for thread_lib in "" pthread pthread32 pthreads thread dce; do
			if test x"$thread_lib" = x; then
				add_thread_lib=""
				IN=""
			else
				add_thread_lib="-l$thread_lib"
				IN=" in -l$thread_lib"
			fi
			if test x"$have_threads" = xposix; then
				defattr=0
			else
				defattr=pthread_attr_default
			fi
			
			LIBS="$add_thread_lib $glib_save_LIBS"
			
			AC_MSG_CHECKING(for pthread_create/pthread_join$IN)
			AC_TRY_RUN(glib_thread_test([$defattr]),
                                   glib_result=yes,
                                   glib_result=no,
                                   [AC_LINK_IFELSE([AC_LANG_SOURCE(glib_thread_test([$defattr]))],
                                                   glib_result=yes,
                                                   glib_result=no)])
                        AC_MSG_RESULT($glib_result)
			
                        if test "$glib_result" = "yes" ; then
			  G_THREAD_LIBS="$add_thread_lib"
                          break
                        fi
		done
		if test "x$G_THREAD_LIBS" = xerror; then
		  AC_MSG_ERROR($LIBS_NOT_FOUND_1$have_threads$LIBS_NOT_FOUND_2)
		fi 
		LIBS="$glib_save_LIBS"
                ;;
            esac
          fi

          glib_save_LIBS="$LIBS"
	  for thread_lib in "" rt rte; do
	    if test x"$thread_lib" = x; then
	      add_thread_lib=""
	      IN=""
	    else
	      add_thread_lib="-l$thread_lib"
	      IN=" in -l$thread_lib"
	    fi
	    LIBS="$add_thread_lib $glib_save_LIBS"
	    
            AC_MSG_CHECKING(for sched_get_priority_min$IN)
	    AC_TRY_RUN(glib_sched_priority_test,
                       glib_result=yes,
                       glib_result=no,
                       [AC_LINK_IFELSE([AC_LANG_SOURCE(glib_sched_priority_test)],
                                       glib_result=yes,
                                       glib_result=no)])
	    AC_MSG_RESULT($glib_result)

	    if test "$glib_result" = "yes" ; then	    
 	       G_THREAD_LIBS="$G_THREAD_LIBS $add_thread_lib"
	       posix_priority_min="sched_get_priority_min(SCHED_OTHER)"
	       posix_priority_max="sched_get_priority_max(SCHED_OTHER)"
	       break
            fi
	  done
	  LIBS="$glib_save_LIBS"
          mutex_has_default=yes
          mutex_default_type='pthread_mutex_t'
          mutex_default_init='PTHREAD_MUTEX_INITIALIZER'
          mutex_header_file='pthread.h'
	  if test "x$have_threads" = "xposix"; then
	    g_threads_impl="POSIX"
	  else
	    g_threads_impl="DCE"
	    have_threads="posix"
	  fi
	  AC_SUBST(GTHREAD_COMPILE_IMPL_DEFINES)
          CPPFLAGS="$glib_save_CPPFLAGS"
          ;;
	win32)
	   g_threads_impl="WIN32"
	   ;;
        none|no)
	   g_threads_impl="NONE"
           ;;
        *)
	   g_threads_impl="NONE"
           G_THREAD_LIBS=error
           ;;
esac

if test "x$G_THREAD_LIBS" = xerror; then
        AC_MSG_ERROR($LIBS_NOT_FOUND_1$have_threads$LIBS_NOT_FOUND_2)
fi

AC_MSG_CHECKING(thread related libraries)
AC_MSG_RESULT($G_THREAD_LIBS)

dnl check for mt safe function variants and some posix functions
dnl ************************************************************

if test x"$have_threads" != xno; then
	glib_save_LIBS="$LIBS"
	# we are not doing the following for now, as this might require glib 
	# to always be linked with the thread libs on some platforms. 
	# LIBS="$LIBS $G_THREAD_LIBS"
	AC_CHECK_FUNCS(localtime_r gmtime_r)
	if test "$ac_cv_header_pwd_h" = "yes"; then
	 	AC_CACHE_CHECK([for posix getpwuid_r],
			ac_cv_func_posix_getpwuid_r,
			[AC_TRY_RUN([
#include <errno.h>
#include <pwd.h>
int main () { 
    char buffer[10000];
    struct passwd pwd, *pwptr = &pwd;
    int error;
    errno = 0;
    error = getpwuid_r (0, &pwd, buffer, 
                        sizeof (buffer), &pwptr);
   return (error < 0 && errno == ENOSYS) 
	   || error == ENOSYS; 
}                               ],
				[ac_cv_func_posix_getpwuid_r=yes],
				[ac_cv_func_posix_getpwuid_r=no])])
		GLIB_ASSERT_SET(ac_cv_func_posix_getpwuid_r)
		if test "$ac_cv_func_posix_getpwuid_r" = yes; then
			AC_DEFINE(HAVE_POSIX_GETPWUID_R,1,
				[Have POSIX function getpwuid_r])
		else
	 		AC_CACHE_CHECK([for nonposix getpwuid_r],
				ac_cv_func_nonposix_getpwuid_r,
				[AC_TRY_LINK([#include <pwd.h>],
                                	[char buffer[10000];
                                	struct passwd pwd;
                                	getpwuid_r (0, &pwd, buffer, 
                                        		sizeof (buffer));],
					[ac_cv_func_nonposix_getpwuid_r=yes],
					[ac_cv_func_nonposix_getpwuid_r=no])])
			GLIB_ASSERT_SET(ac_cv_func_nonposix_getpwuid_r)
			if test "$ac_cv_func_nonposix_getpwuid_r" = yes; then
				AC_DEFINE(HAVE_NONPOSIX_GETPWUID_R,1,
					[Have non-POSIX function getpwuid_r])
			fi
		fi
	fi
	if test "$ac_cv_header_grp_h" = "yes"; then
	   	AC_CACHE_CHECK([for posix getgrgid_r],
			ac_cv_func_posix_getgrgid_r,
			[AC_TRY_RUN([
#include <errno.h>
#include <grp.h>
int main () { 
    char buffer[10000];
    struct group grp, *grpptr = &grp;
    int error;
    errno = 0;
    error = getgrgid_r (0, &grp, buffer, 
                        sizeof (buffer), &grpptr);
   return (error < 0 && errno == ENOSYS) 
	   || error == ENOSYS; 
}                              ],
			       [ac_cv_func_posix_getgrgid_r=yes],
			       [ac_cv_func_posix_getgrgid_r=no])])
		GLIB_ASSERT_SET(ac_cv_func_posix_getgrgid_r)
		if test "$ac_cv_func_posix_getgrgid_r" = yes; then
		   	AC_DEFINE(HAVE_POSIX_GETGRGID_R,1,
				[Have POSIX function getgrgid_r])
		else
			AC_CACHE_CHECK([for nonposix getgrgid_r],
				ac_cv_func_nonposix_getgrgid_r,
				[AC_TRY_LINK([#include <grp.h>],
                               		[char buffer[10000];
					struct group grp;	
					getgrgid_r (0, &grp, buffer, 
                                       	sizeof (buffer));],
				[ac_cv_func_nonposix_getgrgid_r=yes],
				[ac_cv_func_nonposix_getgrgid_r=no])])
			GLIB_ASSERT_SET(ac_cv_func_nonposix_getgrgid_r)
			if test "$ac_cv_func_nonposix_getgrgid_r" = yes; then
			   	AC_DEFINE(HAVE_NONPOSIX_GETGRGID_R,1,
					[Have non-POSIX function getgrgid_r])
			fi
		fi
	fi
	LIBS="$G_THREAD_LIBS $LIBS"
	if test x"$have_threads" = xposix; then
		glib_save_CPPFLAGS="$CPPFLAGS"
		CPPFLAGS="$CPPFLAGS $GTHREAD_COMPILE_IMPL_DEFINES"
		dnl we might grow sizeof(pthread_t) later on, so use a dummy name here
		GLIB_SIZEOF([#include <pthread.h>], pthread_t, system_thread)
		# This is not AC_CHECK_FUNC to also work with function
		# name mangling in header files.
		AC_MSG_CHECKING(for pthread_attr_setstacksize)
		AC_TRY_LINK([#include <pthread.h>],
			[pthread_attr_t t; pthread_attr_setstacksize(&t,0)],
			[AC_MSG_RESULT(yes)
			AC_DEFINE(HAVE_PTHREAD_ATTR_SETSTACKSIZE,1,
				  [Have function pthread_attr_setstacksize])],
			[AC_MSG_RESULT(no)])
		AC_MSG_CHECKING(for minimal/maximal thread priority)
		if test x"$posix_priority_min" = x; then
			AC_EGREP_CPP(PX_PRIO_MIN,[#include <pthread.h>
				PX_PRIO_MIN],,[
				posix_priority_min=PX_PRIO_MIN
				posix_priority_max=PX_PRIO_MAX])
		fi
		if test x"$posix_priority_min" = x; then
			# AIX
			AC_EGREP_CPP(PTHREAD_PRIO_MIN,[#include <pthread.h>
				PTHREAD_PRIO_MIN],,[
				posix_priority_min=PTHREAD_PRIO_MIN
				posix_priority_max=PTHREAD_PRIO_MAX])
		fi
		if test x"$posix_priority_min" = x; then
			AC_EGREP_CPP(PRI_OTHER_MIN,[#include <pthread.h>
				PRI_OTHER_MIN],,[
				posix_priority_min=PRI_OTHER_MIN	
				posix_priority_max=PRI_OTHER_MAX])
		fi
		if test x"$posix_priority_min" = x; then
			AC_MSG_RESULT(none found)
			AC_MSG_WARN($POSIX_NO_PRIORITIES)
	                posix_priority_min=-1
			posix_priority_max=-1
		else
			AC_MSG_RESULT($posix_priority_min/$posix_priority_max)
			AC_MSG_CHECKING(for pthread_setschedparam)
			AC_TRY_LINK([#include <pthread.h>],
		          [pthread_t t; pthread_setschedparam(t, 0, NULL)],
			  [AC_MSG_RESULT(yes)
			AC_DEFINE_UNQUOTED(POSIX_MIN_PRIORITY,$posix_priority_min,[Minimum POSIX RT priority])
			   AC_DEFINE_UNQUOTED(POSIX_MAX_PRIORITY,$posix_priority_max,[Maximum POSIX RT priority])],
                          [AC_MSG_RESULT(no)
                           AC_MSG_WARN($POSIX_NO_PRIORITIES)])
		fi
		posix_yield_func=none
		AC_MSG_CHECKING(for posix yield function)
		for yield_func in sched_yield pthread_yield_np pthread_yield \
							thr_yield; do
			AC_TRY_LINK([#include <pthread.h>],
				[$yield_func()],
				[posix_yield_func="$yield_func"
				break])
		done		
		if test x"$posix_yield_func" = xnone; then
			AC_MSG_RESULT(none found)
			AC_MSG_WARN($POSIX_NO_YIELD)
	                posix_yield_func="g_usleep(1000)"
		else
			AC_MSG_RESULT($posix_yield_func)
			posix_yield_func="$posix_yield_func()"
		fi
		AC_DEFINE_UNQUOTED(POSIX_YIELD_FUNC,$posix_yield_func,[The POSIX RT yield function])
		CPPFLAGS="$glib_save_CPPFLAGS"
           
	elif test x"$have_threads" = xwin32; then
		# It's a pointer to a private struct
		GLIB_SIZEOF(,struct _GThreadData *, system_thread)
	fi

	LIBS="$glib_save_LIBS"

	# now spit out all the warnings.
	if test "$ac_cv_func_posix_getpwuid_r" != "yes" && 
	   test "$ac_cv_func_nonposix_getpwuid_r" != "yes"; then
		AC_MSG_WARN($FUNC_NO_GETPWUID_R)
	fi
	if test "$ac_cv_func_localtime_r" != "yes"; then
		AC_MSG_WARN($FUNC_NO_LOCALTIME_R)
	fi
fi	

if test x"$glib_cv_sizeof_system_thread" = x; then
   # use a pointer as a fallback.
   GLIB_SIZEOF(,void *, system_thread)
fi

#
# Hack to deal with:
# 
#  a) GCC < 3.3 for Linux doesn't include -lpthread when
#     building shared libraries with linux.
#  b) FreeBSD doesn't do this either.
#
case $host in
  *-*-freebsd*|*-*-linux*)
    G_THREAD_LIBS_FOR_GTHREAD="`echo $G_THREAD_LIBS | sed s/-pthread/-lpthread/`"
    ;;
  *-*-openbsd*)
    LDFLAGS="$LDFLAGS -pthread"
    ;;
  *)
    G_THREAD_LIBS_FOR_GTHREAD="$G_THREAD_LIBS"
    ;;
esac

AC_DEFINE_UNQUOTED(G_THREAD_SOURCE,"gthread-$have_threads.c",
		   [Source file containing theread implementation])
AC_SUBST(G_THREAD_CFLAGS)
AC_SUBST(G_THREAD_LIBS)
AC_SUBST(G_THREAD_LIBS_FOR_GTHREAD)
AC_SUBST(G_THREAD_LIBS_EXTRA)

dnl **********************************************
dnl *** GDefaultMutex setup and initialization ***
dnl **********************************************
dnl
dnl if mutex_has_default = yes, we also got
dnl mutex_default_type, mutex_default_init and mutex_header_file
if test $mutex_has_default = yes ; then
	glib_save_CPPFLAGS="$CPPFLAGS"
	glib_save_LIBS="$LIBS"
	LIBS="$G_THREAD_LIBS $LIBS"
	CPPFLAGS="$CPPFLAGS $GTHREAD_COMPILE_IMPL_DEFINES"
	GLIB_SIZEOF([#include <$mutex_header_file>],
                    $mutex_default_type,
                    gmutex)
	GLIB_BYTE_CONTENTS([#include <$mutex_header_file>],
			   $mutex_default_type,
			   gmutex,
			   $glib_cv_sizeof_gmutex,
			   $mutex_default_init)
	if test x"$glib_cv_byte_contents_gmutex" = xno; then
		mutex_has_default=no
	fi
	CPPFLAGS="$glib_save_CPPFLAGS"
	LIBS="$glib_save_LIBS"
fi

dnl ************************
dnl *** g_atomic_* tests ***
dnl ************************

AC_MSG_CHECKING([whether to use assembler code for atomic operations])
    case $host_cpu in
      i386)
        AC_MSG_RESULT([none])
        glib_memory_barrier_needed=no
        ;;
      i?86)
        AC_MSG_RESULT([i486])
        AC_DEFINE_UNQUOTED(G_ATOMIC_I486, 1,
			   [i486 atomic implementation])
        glib_memory_barrier_needed=no
        ;;
      sparc*)
        SPARCV9_WARNING="Try to rerun configure with CFLAGS='-mcpu=v9',
			 when you are using a sparc with v9 instruction set (most
			 sparcs nowadays). This will make the code for atomic
			 operations much faster. The resulting code will not run
			 on very old sparcs though."

        AC_LINK_IFELSE([AC_LANG_SOURCE([[
          main ()
          {
            int tmp1, tmp2, tmp3;
            __asm__ __volatile__("casx [%2], %0, %1"
                                 : "=&r" (tmp1), "=&r" (tmp2) : "r" (&tmp3));
          }]])],
          AC_MSG_RESULT([sparcv9])
          AC_DEFINE_UNQUOTED(G_ATOMIC_SPARCV9, 1,
			     [sparcv9 atomic implementation]),
          AC_MSG_RESULT([no])
          AC_MSG_WARN([[$SPARCV9_WARNING]]))
        glib_memory_barrier_needed=yes
        ;;
      alpha*)
        AC_MSG_RESULT([alpha])
        AC_DEFINE_UNQUOTED(G_ATOMIC_ALPHA, 1,
			   [alpha atomic implementation])
        glib_memory_barrier_needed=yes
        ;;
      x86_64)
        AC_MSG_RESULT([x86_64])
        AC_DEFINE_UNQUOTED(G_ATOMIC_X86_64, 1,
			   [x86_64 atomic implementation])
        glib_memory_barrier_needed=no
       ;;
      powerpc*)
        AC_MSG_RESULT([powerpc])
        AC_DEFINE_UNQUOTED(G_ATOMIC_POWERPC, 1,
			   [powerpc atomic implementation])
        glib_memory_barrier_needed=yes
        AC_MSG_CHECKING([whether asm supports numbered local labels])
        AC_TRY_COMPILE(
		       ,[
		       __asm__ __volatile__ ("1:       nop\n"
			       "         bne-    1b")
		       ],[
		       AC_DEFINE_UNQUOTED(ASM_NUMERIC_LABELS, 1, [define if asm blocks can use numeric local labels])
		       AC_MSG_RESULT([yes])
		       ],[
		       AC_MSG_RESULT([no])
		       ])
        ;;
      ia64)
        AC_MSG_RESULT([ia64])
        AC_DEFINE_UNQUOTED(G_ATOMIC_IA64, 1,
			   [ia64 atomic implementation])
        glib_memory_barrier_needed=yes
        ;;
      s390|s390x)
        AC_MSG_RESULT([s390])
        AC_DEFINE_UNQUOTED(G_ATOMIC_S390, 1,
			   [s390 atomic implementation])
        glib_memory_barrier_needed=no
        ;;
      arm*)
        AC_MSG_RESULT([arm])
        AC_DEFINE_UNQUOTED(G_ATOMIC_ARM, 1,
			   [arm atomic implementation])
        glib_memory_barrier_needed=no
        ;;
      crisv32*|etraxfs*)
        AC_MSG_RESULT([crisv32])
        AC_DEFINE_UNQUOTED(G_ATOMIC_CRISV32, 1,
			   [crisv32 atomic implementation])
        glib_memory_barrier_needed=no
        ;;
      cris*|etrax*)
        AC_MSG_RESULT([cris])
        AC_DEFINE_UNQUOTED(G_ATOMIC_CRIS, 1,
			   [cris atomic implementation])
        glib_memory_barrier_needed=no
        ;;
      *)
        AC_MSG_RESULT([none])
        glib_memory_barrier_needed=yes
        ;;
    esac

glib_cv_gcc_has_builtin_atomic_operations=no
if test x"$GCC" = xyes; then
  AC_MSG_CHECKING([whether GCC supports built-in atomic intrinsics])
  AC_TRY_LINK([],
	      [int i;
	       __sync_synchronize ();
	       __sync_bool_compare_and_swap (&i, 0, 1);
	       __sync_fetch_and_add (&i, 1);
	      ],
	      [glib_cv_gcc_has_builtin_atomic_operations=yes],
	      [glib_cv_gcc_has_builtin_atomic_operations=no])

  AC_MSG_RESULT($glib_cv_gcc_has_builtin_atomic_operations)
fi

AC_MSG_CHECKING([for Win32 atomic intrinsics])
glib_cv_has_win32_atomic_operations=no
AC_TRY_LINK([],
	[int i; _InterlockedExchangeAdd (&i, 0);],
	[glib_cv_has_win32_atomic_operations=yes],
	[glib_cv_has_win32_atomic_operations=no])
AC_MSG_RESULT($glib_cv_has_win32_atomic_operations)
if test "x$glib_cv_has_win32_atomic_operations" = xyes; then
	AC_DEFINE(HAVE_WIN32_BUILTINS_FOR_ATOMIC_OPERATIONS,1,[Have Win32 atomic intrinsics])
fi

dnl ************************
dnl ** Check for futex(2) **
dnl ************************
AC_CACHE_CHECK(for futex(2) system call,
    glib_cv_futex,AC_COMPILE_IFELSE([AC_LANG_PROGRAM([
#include <linux/futex.h>
#include <sys/syscall.h>
#include <unistd.h>
],[
int
main (void)
{
  /* it is not like this actually runs or anything... */
  syscall (__NR_futex, NULL, FUTEX_WAKE, FUTEX_WAIT);
  return 0;
}
])],glib_cv_futex=yes,glib_cv_futex=no))
if test x"$glib_cv_futex" = xyes; then
  AC_DEFINE(HAVE_FUTEX, 1, [we have the futex(2) system call])
fi

dnl this section will only be run if config.status is invoked with no
dnl arguments, or with "$1/glibconfig.h" as an argument.
AC_CONFIG_COMMANDS([$1/glibconfig.h],
[
	outfile=$1/glibconfig.h-tmp
	cat > $outfile <<\_______EOF
/* glibconfig.h
 *
 * This is a generated file.  Please modify 'configure.ac'
 */

#ifndef __G_LIBCONFIG_H__
#define __G_LIBCONFIG_H__

#include <glib/gmacros.h>

_______EOF

	if test x$glib_limits_h = xyes; then
	  echo '#include <limits.h>' >> $outfile
	fi
	if test x$glib_float_h = xyes; then
	  echo '#include <float.h>' >> $outfile
	fi
	if test x$glib_values_h = xyes; then
	  echo '#include <values.h>' >> $outfile
	fi
	if test "$glib_header_alloca_h" = "yes"; then
	  echo '#define GLIB_HAVE_ALLOCA_H' >> $outfile
	fi
	if test x$glib_sys_poll_h = xyes; then
	  echo '#define GLIB_HAVE_SYS_POLL_H' >> $outfile
	fi
	if test x$glib_included_printf != xyes; then
          echo "
/* Specifies that GLib's g_print*() functions wrap the
 * system printf functions.  This is useful to know, for example,
 * when using glibc's register_printf_function().
 */" >> $outfile
	  echo '#define GLIB_USING_SYSTEM_PRINTF' >> $outfile
	fi

	cat >> $outfile <<_______EOF

G_BEGIN_DECLS

#define G_MINFLOAT	$glib_mf
#define G_MAXFLOAT	$glib_Mf
#define G_MINDOUBLE	$glib_md
#define G_MAXDOUBLE	$glib_Md
#define G_MINSHORT	$glib_ms
#define G_MAXSHORT	$glib_Ms
#define G_MAXUSHORT	$glib_Mus
#define G_MININT	$glib_mi
#define G_MAXINT	$glib_Mi
#define G_MAXUINT	$glib_Mui
#define G_MINLONG	$glib_ml
#define G_MAXLONG	$glib_Ml
#define G_MAXULONG	$glib_Mul

_______EOF


	### this should always be true in a modern C/C++ compiler
	cat >>$outfile <<_______EOF
typedef signed char gint8;
typedef unsigned char guint8;
_______EOF


	if test -n "$gint16"; then
	  cat >>$outfile <<_______EOF
typedef signed $gint16 gint16;
typedef unsigned $gint16 guint16;
#define G_GINT16_MODIFIER $gint16_modifier
#define G_GINT16_FORMAT $gint16_format
#define G_GUINT16_FORMAT $guint16_format
_______EOF
	fi


	if test -n "$gint32"; then
	  cat >>$outfile <<_______EOF
typedef signed $gint32 gint32;
typedef unsigned $gint32 guint32;
#define G_GINT32_MODIFIER $gint32_modifier
#define G_GINT32_FORMAT $gint32_format
#define G_GUINT32_FORMAT $guint32_format
_______EOF
	fi

	cat >>$outfile <<_______EOF
#define G_HAVE_GINT64 1          /* deprecated, always true */

${glib_extension}typedef signed $gint64 gint64;
${glib_extension}typedef unsigned $gint64 guint64;

#define G_GINT64_CONSTANT(val)	$gint64_constant
#define G_GUINT64_CONSTANT(val)	$guint64_constant
_______EOF

	if test x$gint64_format != x ; then
	  cat >>$outfile <<_______EOF
#define G_GINT64_MODIFIER $gint64_modifier
#define G_GINT64_FORMAT $gint64_format
#define G_GUINT64_FORMAT $guint64_format
_______EOF
        else
	  cat >>$outfile <<_______EOF
#undef G_GINT64_MODIFIER
#undef G_GINT64_FORMAT
#undef G_GUINT64_FORMAT
_______EOF
        fi           

        cat >>$outfile <<_______EOF

#define GLIB_SIZEOF_VOID_P $glib_void_p
#define GLIB_SIZEOF_LONG   $glib_long
#define GLIB_SIZEOF_SIZE_T $glib_size_t

_______EOF

        cat >>$outfile <<_______EOF
typedef signed $glib_size_type_define gssize;
typedef unsigned $glib_size_type_define gsize;
#define G_GSIZE_MODIFIER $gsize_modifier
#define G_GSSIZE_FORMAT $gssize_format
#define G_GSIZE_FORMAT $gsize_format

#define G_MAXSIZE	G_MAXU$glib_msize_type
#define G_MINSSIZE	G_MIN$glib_msize_type
#define G_MAXSSIZE	G_MAX$glib_msize_type

typedef gint64 goffset;
#define G_MINOFFSET	G_MININT64
#define G_MAXOFFSET	G_MAXINT64

#define G_GOFFSET_MODIFIER      G_GINT64_MODIFIER
#define G_GOFFSET_FORMAT        G_GINT64_FORMAT
#define G_GOFFSET_CONSTANT(val) G_GINT64_CONSTANT(val)

_______EOF

	if test -z "$glib_unknown_void_p"; then
	  cat >>$outfile <<_______EOF

#define GPOINTER_TO_INT(p)	((gint)  ${glib_gpi_cast} (p))
#define GPOINTER_TO_UINT(p)	((guint) ${glib_gpui_cast} (p))

#define GINT_TO_POINTER(i)	((gpointer) ${glib_gpi_cast} (i))
#define GUINT_TO_POINTER(u)	((gpointer) ${glib_gpui_cast} (u))

typedef signed $glib_intptr_type_define gintptr;
typedef unsigned $glib_intptr_type_define guintptr;

#define G_GINTPTR_MODIFIER      $gintptr_modifier
#define G_GINTPTR_FORMAT        $gintptr_format
#define G_GUINTPTR_FORMAT       $guintptr_format
_______EOF
	else
	  echo '#error SIZEOF_VOID_P unknown - This should never happen' >>$outfile
	fi



	cat >>$outfile <<_______EOF
$glib_atexit
$glib_memmove
$glib_defines
$glib_os
$glib_static_compilation

$glib_vacopy

#ifdef	__cplusplus
#define	G_HAVE_INLINE	1
#else	/* !__cplusplus */
$glib_inline
#endif	/* !__cplusplus */

#ifdef	__cplusplus
#define G_CAN_INLINE	1
_______EOF

	if test x$g_can_inline = xyes ; then
		cat >>$outfile <<_______EOF
#else	/* !__cplusplus */
#define G_CAN_INLINE	1
_______EOF
	fi

	cat >>$outfile <<_______EOF
#endif

_______EOF

	if test x$g_have_iso_c_varargs = xyes ; then
		cat >>$outfile <<_______EOF
#ifndef __cplusplus
# define G_HAVE_ISO_VARARGS 1
#endif
_______EOF
	fi
	if test x$g_have_iso_cxx_varargs = xyes ; then
		cat >>$outfile <<_______EOF
#ifdef __cplusplus
# define G_HAVE_ISO_VARARGS 1
#endif
_______EOF
	fi
	if test x$g_have_gnuc_varargs = xyes ; then
		cat >>$outfile <<_______EOF

/* gcc-2.95.x supports both gnu style and ISO varargs, but if -ansi
 * is passed ISO vararg support is turned off, and there is no work
 * around to turn it on, so we unconditionally turn it off.
 */
#if __GNUC__ == 2 && __GNUC_MINOR__ == 95
#  undef G_HAVE_ISO_VARARGS
#endif

#define G_HAVE_GNUC_VARARGS 1
_______EOF
	fi

	echo >>$outfile
	if test x$g_have_eilseq = xno; then
		cat >>$outfile <<_______EOF
#ifndef EILSEQ
/* On some systems, like SunOS and NetBSD, EILSEQ is not defined.
 * The correspondence between this and the corresponding definition
 * in libiconv is essential.
 */
#  define EILSEQ ENOENT
#endif
_______EOF

	fi

	if test x$g_have_gnuc_visibility = xyes; then
		cat >>$outfile <<_______EOF
#define G_HAVE_GNUC_VISIBILITY 1
_______EOF
	fi
		cat >>$outfile <<_______EOF
#if defined(__SUNPRO_C) && (__SUNPRO_C >= 0x590)
#define G_GNUC_INTERNAL __attribute__((visibility("hidden")))
#elif defined(__SUNPRO_C) && (__SUNPRO_C >= 0x550)
#define G_GNUC_INTERNAL __hidden
#elif defined (__GNUC__) && defined (G_HAVE_GNUC_VISIBILITY)
#define G_GNUC_INTERNAL __attribute__((visibility("hidden")))
#else
#define G_GNUC_INTERNAL
#endif 
_______EOF


	echo >>$outfile
	if test x$g_mutex_has_default = xyes; then
		cat >>$outfile <<_______EOF
$g_enable_threads_def G_THREADS_ENABLED
#define G_THREADS_IMPL_$g_threads_impl_def
typedef struct _GStaticMutex GStaticMutex;
struct _GStaticMutex
{
  struct _GMutex *runtime_mutex;
  union {
    char   pad[[$g_mutex_sizeof]];
    double dummy_double;
    void  *dummy_pointer;
    long   dummy_long;
  } static_mutex;
};
#define	G_STATIC_MUTEX_INIT	{ NULL, { { $g_mutex_contents} } }
#define	g_static_mutex_get_mutex(mutex) \\
  (g_thread_use_default_impl ? ((GMutex*)(gpointer) ((mutex)->static_mutex.pad)) : \\
   g_static_mutex_get_mutex_impl_shortcut (&((mutex)->runtime_mutex)))
_______EOF
	else
		cat >>$outfile <<_______EOF
$g_enable_threads_def G_THREADS_ENABLED
#define G_THREADS_IMPL_$g_threads_impl_def
typedef struct _GMutex* GStaticMutex;
#define G_STATIC_MUTEX_INIT NULL
#define g_static_mutex_get_mutex(mutex) \\
  (g_static_mutex_get_mutex_impl_shortcut (mutex))
_______EOF
	fi

	cat >>$outfile <<_______EOF
/* This represents a system thread as used by the implementation. An
 * alien implementaion, as loaded by g_thread_init can only count on
 * "sizeof (gpointer)" bytes to store their info. We however need more
 * for some of our native implementations. */
typedef union _GSystemThread GSystemThread;
union _GSystemThread
{
  char   data[[$g_system_thread_sizeof]];
  double dummy_double;
  void  *dummy_pointer;
  long   dummy_long;
};
_______EOF
	if test x"$g_memory_barrier_needed" != xno; then
	  echo >>$outfile
	  echo "#define G_ATOMIC_OP_MEMORY_BARRIER_NEEDED 1" >>$outfile
	fi
	if test x"$g_gcc_atomic_ops" != xno; then
          echo >>$outfile
          echo "#define G_ATOMIC_OP_USE_GCC_BUILTINS 1" >>$outfile
        fi
	echo >>$outfile
	g_bit_sizes="16 32 64"
	for bits in $g_bit_sizes; do
	  cat >>$outfile <<_______EOF
#define GINT${bits}_TO_${g_bs_native}(val)	((gint${bits}) (val))
#define GUINT${bits}_TO_${g_bs_native}(val)	((guint${bits}) (val))
#define GINT${bits}_TO_${g_bs_alien}(val)	((gint${bits}) GUINT${bits}_SWAP_LE_BE (val))
#define GUINT${bits}_TO_${g_bs_alien}(val)	(GUINT${bits}_SWAP_LE_BE (val))
_______EOF
	done

	cat >>$outfile <<_______EOF
#define GLONG_TO_LE(val)	((glong) GINT${glongbits}_TO_LE (val))
#define GULONG_TO_LE(val)	((gulong) GUINT${glongbits}_TO_LE (val))
#define GLONG_TO_BE(val)	((glong) GINT${glongbits}_TO_BE (val))
#define GULONG_TO_BE(val)	((gulong) GUINT${glongbits}_TO_BE (val))
#define GINT_TO_LE(val)		((gint) GINT${gintbits}_TO_LE (val))
#define GUINT_TO_LE(val)	((guint) GUINT${gintbits}_TO_LE (val))
#define GINT_TO_BE(val)		((gint) GINT${gintbits}_TO_BE (val))
#define GUINT_TO_BE(val)	((guint) GUINT${gintbits}_TO_BE (val))
#define GSIZE_TO_LE(val)	((gsize) GUINT${gsizebits}_TO_LE (val))
#define GSSIZE_TO_LE(val)	((gssize) GINT${gsizebits}_TO_LE (val))
#define GSIZE_TO_BE(val)	((gsize) GUINT${gsizebits}_TO_BE (val))
#define GSSIZE_TO_BE(val)	((gssize) GINT${gsizebits}_TO_BE (val))
#define G_BYTE_ORDER $g_byte_order

#define G_MODULE_SUFFIX "$g_module_suffix"

/* A GPid is an abstraction for a process "handle". It is *not* an
 * abstraction for a process identifier in general. GPid is used in
 * GLib only for descendant processes spawned with the g_spawn*
 * functions. On POSIX there is no "process handle" concept as such,
 * but on Windows a GPid is a handle to a process, a kind of pointer,
 * not a process identifier.
 */
typedef $g_pid_type GPid;

G_END_DECLS

#endif /* GLIBCONFIG_H */
_______EOF


	if cmp -s $outfile $1/glibconfig.h; then
	  AC_MSG_NOTICE([$1/glibconfig.h is unchanged])
	  rm -f $outfile
	else
	  mv $outfile $1/glibconfig.h
	fi
],[

# Note that if two cases are the same, case goes with the first one.
# Note also that this is inside an AC_OUTPUT_COMMAND.  We do not depend
# on variable expansion in case labels.  Look at the generated config.status
# for a hint.

if test "x${ac_cv_working_alloca_h+set}" = xset ; then
  glib_header_alloca_h="$ac_cv_working_alloca_h"
else
  glib_header_alloca_h="$ac_cv_header_alloca_h"
fi

case xyes in
x$ac_cv_header_float_h)
  glib_float_h=yes
  glib_mf=FLT_MIN glib_Mf=FLT_MAX
  glib_md=DBL_MIN glib_Md=DBL_MAX
  ;;
x$ac_cv_header_values_h)
  glib_values_h=yes
  glib_mf=MINFLOAT  glib_Mf=MAXFLOAT
  glib_md=MINDOUBLE glib_Md=MAXDOUBLE
  ;;
esac

case xyes in
x$ac_cv_header_limits_h)
  glib_limits_h=yes
  glib_ms=SHRT_MIN glib_Ms=SHRT_MAX glib_Mus=USHRT_MAX
  glib_mi=INT_MIN  glib_Mi=INT_MAX  glib_Mui=UINT_MAX
  glib_ml=LONG_MIN glib_Ml=LONG_MAX glib_Mul=ULONG_MAX
  ;;
x$ac_cv_header_values_h)
  glib_values_h=yes
  glib_ms=MINSHORT glib_Ms=MAXSHORT glib_Mus="(((gushort)G_MAXSHORT)*2+1)"
  glib_mi=MININT   glib_Mi=MAXINT   glib_Mui="(((guint)G_MAXINT)*2+1)"
  glib_ml=MINLONG  glib_Ml=MAXLONG  glib_Mul="(((gulong)G_MAXLONG)*2+1)"
  ;;
esac

if test x$ac_cv_header_sys_poll_h = xyes ; then
  glib_sys_poll_h=yes
fi

if test x$enable_included_printf = xyes ; then
  glib_included_printf=yes
fi

case x2 in
x$ac_cv_sizeof_short)		
  gint16=short
  gint16_modifier='"h"'
  gint16_format='"hi"'
  guint16_format='"hu"'
  ;;
x$ac_cv_sizeof_int)		
  gint16=int
  gint16_modifier='""'
  gint16_format='"i"'
  guint16_format='"u"'
  ;;
esac
case x4 in
x$ac_cv_sizeof_short)		
  gint32=short
  gint32_modifier='"h"'
  gint32_format='"hi"'
  guint32_format='"hu"'
  ;;
x$ac_cv_sizeof_int)		
  gint32=int
  gint32_modifier='""'
  gint32_format='"i"'
  guint32_format='"u"'
  ;;
x$ac_cv_sizeof_long)		
  gint32=long
  gint32_modifier='"l"'
  gint32_format='"li"'
  guint32_format='"lu"'
  ;;
esac
case x8 in
x$ac_cv_sizeof_int)
  gint64=int
  gint64_modifier='""'
  gint64_format='"i"'
  guint64_format='"u"'
  glib_extension=
  gint64_constant='(val)'
  guint64_constant='(val)'
  ;;
x$ac_cv_sizeof_long)
  gint64=long
  gint64_modifier='"l"'
  gint64_format='"li"'
  guint64_format='"lu"'
  glib_extension=
  gint64_constant='(val##L)'
  guint64_constant='(val##UL)'
  ;;
x$ac_cv_sizeof_long_long)
  gint64='long long'
  if test -n "$glib_cv_long_long_format"; then
    gint64_modifier='"'$glib_cv_long_long_format'"'
    gint64_format='"'$glib_cv_long_long_format'i"'
    guint64_format='"'$glib_cv_long_long_format'u"'
  fi
  glib_extension='G_GNUC_EXTENSION '
  gint64_constant='(G_GNUC_EXTENSION (val##LL))'
  guint64_constant='(G_GNUC_EXTENSION (val##ULL))'
  ;;
x$ac_cv_sizeof___int64)
  gint64='__int64'
  if test -n "$glib_cv_long_long_format"; then
    gint64_modifier='"'$glib_cv_long_long_format'"'
    gint64_format='"'$glib_cv_long_long_format'i"'
    guint64_format='"'$glib_cv_long_long_format'u"'
  fi
  glib_extension=
  gint64_constant='(val##i64)'
  guint64_constant='(val##ui64)'
  ;;
esac
glib_size_t=$ac_cv_sizeof_size_t
glib_size_type_define="$glib_size_type"
glib_void_p=$ac_cv_sizeof_void_p
glib_long=$ac_cv_sizeof_long

case "$glib_size_type" in
short)
  gsize_modifier='"h"'
  gsize_format='"hu"'
  gssize_format='"hi"'
  glib_msize_type='SHRT'
  ;;
int)
  gsize_modifier='""'
  gsize_format='"u"'
  gssize_format='"i"'
  glib_msize_type='INT'
  ;;
long)
  gsize_modifier='"l"'
  gsize_format='"lu"'
  gssize_format='"li"'
  glib_msize_type='LONG'
  ;;
"long long"|__int64)
  gsize_modifier='"I64"'
  gsize_format='"I64u"'
  gssize_format='"I64i"'
  glib_msize_type='INT64'
  ;;
esac

gintbits=`expr $ac_cv_sizeof_int \* 8 2>/dev/null`
glongbits=`expr $ac_cv_sizeof_long \* 8 2>/dev/null`
gsizebits=`expr $ac_cv_sizeof_size_t \* 8 2>/dev/null`

case x"$ac_cv_sizeof_void_p" in
x$ac_cv_sizeof_int)
  glib_intptr_type_define=int
  gintptr_modifier='""'
  gintptr_format='"i"'
  guintptr_format='"u"'
  glib_gpi_cast=''
  glib_gpui_cast=''
  ;;
x$ac_cv_sizeof_long)
  glib_intptr_type_define=long
  gintptr_modifier='"l"'
  gintptr_format='"li"'
  guintptr_format='"lu"'
  glib_gpi_cast='(glong)'
  glib_gpui_cast='(gulong)'
  ;;
x$ac_cv_sizeof_long_long)
  glib_intptr_type_define='long long'
  gintptr_modifier='"I64"'
  gintptr_format='"I64i"'
  guintptr_format='"I64u"'
  glib_gpi_cast='(gint64)'
  glib_gpui_cast='(guint64)'
  ;;
x$ac_cv_sizeof___int64)
  glib_intptr_type_define=__int64
  gintptr_modifier='"I64"'
  gintptr_format='"I64i"'
  guintptr_format='"I64u"'
  glib_gpi_cast='(gint64)'
  glib_gpui_cast='(guint64)'
  ;;
*)
  glib_unknown_void_p=yes
  ;;
esac


case xyes in
x$ac_cv_func_atexit)
  glib_atexit="
#ifdef NeXT /* @#%@! NeXTStep */
# define g_ATEXIT(proc)	(!atexit (proc))
#else
# define g_ATEXIT(proc)	(atexit (proc))
#endif"
  ;;
x$ac_cv_func_on_exit)
  glib_atexit="
#define g_ATEXIT(proc)	(on_exit ((void (*)(int, void*))(proc), NULL))"
  ;;
esac

case xyes in
x$ac_cv_func_memmove)
  glib_memmove='
#define g_memmove(dest,src,len) G_STMT_START { memmove ((dest), (src), (len)); } G_STMT_END'
  ;;
x$glib_cv_working_bcopy)
  glib_memmove="
/* memmove isn't available, but bcopy can copy overlapping memory regions */
#define g_memmove(d,s,n) G_STMT_START { bcopy ((s), (d), (n)); } G_STMT_END"
  ;;
*)  
  glib_memmove="
/* memmove isn't found and bcopy can't copy overlapping memory regions, 
 * so we have to roll our own copy routine. */
void g_memmove (void* dest, const void * src, unsigned long len);"
  ;;
esac

glib_defines="
#define GLIB_MAJOR_VERSION $GLIB_MAJOR_VERSION
#define GLIB_MINOR_VERSION $GLIB_MINOR_VERSION
#define GLIB_MICRO_VERSION $GLIB_MICRO_VERSION
"

case xyes in
x$glib_cv_va_copy)	glib_vacopy='#define G_VA_COPY	va_copy' ;;
x$glib_cv___va_copy)	glib_vacopy='#define G_VA_COPY	__va_copy' ;;
*)			glib_vacopy=''
esac

if test x$glib_cv_va_val_copy = xno; then
  glib_vacopy="\$glib_vacopy
#define G_VA_COPY_AS_ARRAY 1"
fi

if test x$glib_cv_hasinline = xyes; then
    glib_inline='#define G_HAVE_INLINE 1'
fi
if test x$glib_cv_has__inline = xyes; then
    glib_inline="\$glib_inline
#define G_HAVE___INLINE 1"
fi
if test x$glib_cv_has__inline__ = xyes; then
    glib_inline="\$glib_inline
#define G_HAVE___INLINE__ 1"
fi

g_have_gnuc_varargs=$g_have_gnuc_varargs
g_have_iso_c_varargs=$g_have_iso_c_varargs
g_have_iso_cxx_varargs=$g_have_iso_cxx_varargs

g_can_inline=$g_can_inline
g_have_gnuc_visibility=$g_have_gnuc_visibility
g_have_sunstudio_visibility=$g_have_sunstudio_visibility

if test x$ac_cv_c_bigendian = xyes; then
  g_byte_order=G_BIG_ENDIAN
  g_bs_native=BE
  g_bs_alien=LE
else
  g_byte_order=G_LITTLE_ENDIAN
  g_bs_native=LE
  g_bs_alien=BE
fi

g_pollin=$glib_cv_value_POLLIN
g_pollout=$glib_cv_value_POLLOUT
g_pollpri=$glib_cv_value_POLLPRI
g_pollhup=$glib_cv_value_POLLHUP
g_pollerr=$glib_cv_value_POLLERR
g_pollnval=$glib_cv_value_POLLNVAL

g_af_unix=$glib_cv_value_AF_UNIX
g_af_inet=$glib_cv_value_AF_INET
g_af_inet6=$glib_cv_value_AF_INET6

g_msg_peek=$glib_cv_value_MSG_PEEK
g_msg_oob=$glib_cv_value_MSG_OOB
g_msg_dontroute=$glib_cv_value_MSG_DONTROUTE

g_have_eilseq=$have_eilseq

case x$have_threads in
xno)	g_enable_threads_def="#undef";;
*)	g_enable_threads_def="#define";;
esac

g_threads_impl_def=$g_threads_impl

g_mutex_has_default="$mutex_has_default"
g_mutex_sizeof="$glib_cv_sizeof_gmutex"
g_system_thread_sizeof="$glib_cv_sizeof_system_thread"
g_mutex_contents="$glib_cv_byte_contents_gmutex"

g_memory_barrier_needed="$glib_memory_barrier_needed"
g_gcc_atomic_ops="$glib_cv_gcc_has_builtin_atomic_operations"

g_module_suffix="$glib_gmodule_suffix"

g_pid_type="$glib_pid_type"
case $host in
  *-*-beos*)
    glib_os="#define G_OS_BEOS"
    ;;
  *-*-cygwin*)
    glib_os="#define G_OS_UNIX
#define G_PLATFORM_WIN32
#define G_WITH_CYGWIN"
    ;;
  *-*-mingw*)
    glib_os="#define G_OS_WIN32
#define G_PLATFORM_WIN32"
    ;;
  *)
    glib_os="#define G_OS_UNIX"
    ;;
esac
glib_static_compilation=""
if test x$glib_win32_static_compilation = xyes; then
  glib_static_compilation="#define GLIB_STATIC_COMPILATION 1
#define GOBJECT_STATIC_COMPILATION 1"
fi
])dnl AC_CONFIG_COMMANDS

])dnl AC_DEFUN

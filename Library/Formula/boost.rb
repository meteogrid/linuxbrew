require 'formula'

class UniversalPython < Requirement
  satisfy(:build_env => false) { archs_for_command("python").universal? }

  def message; <<-EOS.undent
    A universal build was requested, but Python is not a universal build

    Boost compiles against the Python it finds in the path; if this Python
    is not a universal build then linking will likely fail.
    EOS
  end
end

class Boost < Formula
  homepage 'http://www.boost.org'
  url 'http://downloads.sourceforge.net/project/boost/boost/1.54.0/boost_1_54_0.tar.bz2'
  sha1 '230782c7219882d0fab5f1effbe86edb85238bf4'

  head 'http://svn.boost.org/svn/boost/trunk'

  bottle do
    cellar :any
    sha1 '767a67f4400e5273db3443e10a6e07704b4cbd0f' => :mountain_lion
    sha1 '5f487b4a1d131722dd673d7ee2de418adf3b5322' => :lion
    sha1 'cedd9bd34e6dbebc073beeb12fb3aa7a3cb5ecb6' => :snow_leopard
  end

  env :userpaths

  option :universal
  option 'with-icu', 'Build regexp engine with icu support'
  option 'with-c++11', 'Compile using Clang, std=c++11 and stdlib=libc++' if MacOS.version >= :lion
  option 'without-single', 'Disable building single-threading variant'
  option 'without-static', 'Disable building static library variant'

  depends_on 'libbzip2'
  depends_on 'zlib'
  depends_on :python => :recommended
  depends_on UniversalPython if build.universal? and build.with? "python"
  depends_on "icu4c" if build.with? 'icu'
  depends_on :mpi => [:cc, :cxx, :optional]

  fails_with :llvm do
    build 2335
    cause "Dropped arguments to functions when linking with boost"
  end

  def patches
    # upstream backported patches for 1.54.0: http://www.boost.org/patches
    [
      'http://www.boost.org/patches/1_54_0/001-coroutine.patch',
      'http://www.boost.org/patches/1_54_0/002-date-time.patch',
      'http://www.boost.org/patches/1_54_0/003-log.patch',
      'http://www.boost.org/patches/1_54_0/004-thread.patch'
    ] unless build.head?
  end

  def install
    # https://svn.boost.org/trac/boost/ticket/8841
    if build.with? 'mpi' and not build.without? 'single'
      raise <<-EOS.undent
        Building MPI support for both single and multi-threaded flavors
        is not supported.  Please use '--with-mpi' together with
        '--without-single'.
      EOS
    end

    ENV.universal_binary if build.universal?

    # Adjust the name the libs are installed under to include the path to the
    # Homebrew lib directory so executables will work when installed to a
    # non-/usr/local location.
    #
    # otool -L `which mkvmerge`
    # /usr/local/bin/mkvmerge:
    #   libboost_regex-mt.dylib (compatibility version 0.0.0, current version 0.0.0)
    #   libboost_filesystem-mt.dylib (compatibility version 0.0.0, current version 0.0.0)
    #   libboost_system-mt.dylib (compatibility version 0.0.0, current version 0.0.0)
    #
    # becomes:
    #
    # /usr/local/bin/mkvmerge:
    #   /usr/local/lib/libboost_regex-mt.dylib (compatibility version 0.0.0, current version 0.0.0)
    #   /usr/local/lib/libboost_filesystem-mt.dylib (compatibility version 0.0.0, current version 0.0.0)
    #   /usr/local/lib/libboost_system-mt.dylib (compatibility version 0.0.0, current version 0.0.0)
    inreplace 'tools/build/v2/tools/darwin.jam', '-install_name "', "-install_name \"#{HOMEBREW_PREFIX}/lib/"

    # boost will try to use cc, even if we'd rather it use, say, gcc-4.2
    inreplace 'tools/build/v2/engine/build.sh', 'BOOST_JAM_CC=cc', "BOOST_JAM_CC=#{ENV.cc}"
    inreplace 'tools/build/v2/engine/build.jam', 'toolset darwin cc', "toolset darwin #{ENV.cc}"

    # Force boost to compile using the appropriate GCC version
    open("user-config.jam", "a") do |file|
      file.write "using darwin : : #{ENV.cxx} ;\n" if OS.mac?
      file.write "using mpi ;\n" if build.with? 'mpi'
    end

    # we specify libdir too because the script is apparently broken
    bargs = ["--prefix=#{prefix}", "--libdir=#{lib}"]

    icu4c_prefix = Formula.factory('icu4c').opt_prefix
    bargs << "--with-icu=#{icu4c_prefix}"

    # Handle libraries that will not be built.
    without_libraries = []

    # The context library is implemented as x86_64 ASM, so it
    # won't build on PPC or 32-bit builds
    # see https://github.com/mxcl/homebrew/issues/17646
    if Hardware::CPU.type == :ppc || Hardware::CPU.is_32_bit? || build.universal?
      without_libraries << "context"
      # The coroutine library depends on the context library.
      without_libraries << "coroutine"
    end

    # Boost.Log cannot be built using Apple GCC at the moment. Disabled
    # on such systems.
    without_libraries << "log" if ENV.compiler == :gcc || ENV.compiler == :llvm

    without_libraries << "python" if build.without? 'python'
    without_libraries << "mpi" if build.without? 'mpi'

    bargs << "--without-libraries=#{without_libraries.join(',')}"

    args = ["--prefix=#{prefix}",
            "--libdir=#{lib}",
            "-d2",
            "-j#{ENV.make_jobs}",
            "--layout=tagged",
            "--user-config=user-config.jam",
            "install"]

    if build.include? 'without-single'
      args << "threading=multi"
    else
      args << "threading=multi,single"
    end

    if build.include? 'without-static'
      args << "link=shared"
    else
      args << "link=shared,static"
    end

    if MacOS.version >= :lion and build.with? 'c++11'
      args << "cxxflags=-std=c++11" << "cxxflags=-stdlib=libc++"
      args << "linkflags=-stdlib=libc++"
    end

    args << "address-model=32_64" << "architecture=x86" << "pch=off" if build.universal?

    args << "-sBZIP2_INCLUDE=#{Formula.factory('libbzip2').prefix}/include"
    args << "-sBZIP2_LIBPATH=#{Formula.factory('libbzip2').prefix}/lib"
    args << "-sZLIB_INCLUDE=#{Formula.factory('zlib').prefix}/include"
    args << "-sZLIB_LIBPATH=#{Formula.factory('zlib').prefix}/lib"

    system "./bootstrap.sh", *bargs
    system "./b2", *args
  end

  def caveats
    s = ''
    # ENV.compiler doesn't exist in caveats. Check library availability
    # instead.
    if Dir.glob("#{lib}/libboost_log*").empty?
      s += <<-EOS.undent

      Building of Boost.Log is disabled because it requires newer GCC or Clang.
      EOS
    end

    if Hardware::CPU.type == :ppc || Hardware::CPU.is_32_bit? || build.universal?
      s += <<-EOS.undent

      Building of Boost.Context and Boost.Coroutine is disabled as they are
      only supported on x86_64.
      EOS
    end

    if pour_bottle? and Formula.factory('python').installed?
      s += <<-EOS.undent

      The Boost bottle's module will not import into a Homebrew-installed Python.
      If you use the Boost Python module then please:
        brew install boost --build-from-source
      EOS
    end
    s
  end
end

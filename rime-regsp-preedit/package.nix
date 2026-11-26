{
  stdenv,
  cmake,
  pkg-config,
  boost,
  glog,
  librime,
  version,
}:

stdenv.mkDerivation {
  pname = "rime-regsp-preedit";
  inherit version;

  src = ./.;

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    boost
    glog
    librime
  ];

  cmakeFlags = [
    "-DLIBRIME_SOURCE_DIR=${librime.src}"
  ];

  installPhase = ''
    runHook preInstall
    cmake --install . --prefix "$out"
    runHook postInstall
  '';

  passthru = {
    inherit librime;
  };
}

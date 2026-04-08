function buildAllMex()
    % buildAllMex  Compile all WaveSurfer MEX files for the current MATLAB version.
    %
    % Run this from the WaveSurfer root directory:
    %   buildAllMex()
    %
    % Requires a supported C/C++ compiler configured in MATLAB.
    % On Windows: Visual Studio 2019+ or MinGW-w64
    % Run "mex -setup" to configure if needed.
    
    fprintf('Building WaveSurfer MEX files for MATLAB %s...\n', version) ;
    
    thisDir = fileparts(mfilename('fullpath')) ;
    wsDir = thisDir ;  % this script lives in the WS root
    mexSrcDir = fullfile(wsDir, '+ws', 'mex') ;
    outputDir = fullfile(wsDir, '+ws') ;
    
    %% 1. minMaxDownsampleMex
    fprintf('  Compiling minMaxDownsampleMex...\n') ;
    srcFile = fullfile(mexSrcDir, 'minMaxDownsampleMex', 'minMaxDownsampleMex.cpp') ;
    mex('-largeArrayDims', '-R2017b', '-outdir', outputDir, srcFile) ;
    fprintf('    Done.\n') ;
    
    %% 2. scaledDoubleAnalogDataFromRawMex
    fprintf('  Compiling scaledDoubleAnalogDataFromRawMex...\n') ;
    srcFile = fullfile(mexSrcDir, 'scaledDoubleAnalogDataFromRawMex', 'scaledDoubleAnalogDataFromRawMex.cpp') ;
    mex('-largeArrayDims', '-R2017b', '-outdir', outputDir, srcFile) ;
    fprintf('    Done.\n') ;
    
    %% 3. hideMatlabWindow (Windows only)
    if ispc()
        fprintf('  Compiling hideMatlabWindow...\n') ;
        srcFile = fullfile(wsDir, '+ws', 'hideMatlabWindow.c') ;
        mex('-largeArrayDims', '-outdir', outputDir, srcFile) ;
        fprintf('    Done.\n') ;
    else
        fprintf('  Skipping hideMatlabWindow (Windows only).\n') ;
    end
    
    fprintf('All MEX files built successfully.\n') ;
end

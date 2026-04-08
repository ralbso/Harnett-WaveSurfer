function verifyAllPhases()
    % verifyAllPhases — Quick verification that Phases 1-4 changes are consistent.
    % Run this from the WaveSurfer root directory.
    
    fprintf('=== WaveSurfer Modernization Verification ===\n\n') ;
    nPass = 0 ;
    nFail = 0 ;
    
    % --- Phase 1: Compatibility ---
    fprintf('--- Phase 1: Compatibility ---\n') ;
    
    % Version string
    v = ws.versionString() ;
    check('Version string updated', contains(v, '1.0.0')) ;
    
    % Built-in contains
    check('ws.contains raises deprecation', ...
          checkThrows(@() ws.contains({'a'}, 'a'))) ;
    
    % --- Phase 2: Hardware Layer ---
    fprintf('\n--- Phase 2: Hardware Layer ---\n') ;
    
    % Check that device enumeration uses daqlist
    src = fileread(fullfile('+ws', 'getAllDeviceNamesFromHardware.m')) ;
    check('getAllDeviceNamesFromHardware uses daqlist', contains(src, 'daqlist')) ;
    check('getAllDeviceNamesFromHardware no +dabs', ~contains(src, 'ws.dabs')) ;
    
    src = fileread(fullfile('+ws', 'AITask.m')) ;
    check('AITask uses daq("ni")', contains(src, 'daq("ni")')) ;
    check('AITask no +dabs', ~contains(src, 'ws.dabs')) ;
    check('AITask returns doubles', contains(src, 'DOUBLE') || contains(src, 'double')) ;
    
    src = fileread(fullfile('+ws', 'AOTask.m')) ;
    check('AOTask uses daq("ni")', contains(src, 'daq("ni")')) ;
    check('AOTask preserves Harnett Cmd I mod', contains(src, 'Cmd I')) ;
    
    src = fileread(fullfile('+ws', 'SamplesBuffer.m')) ;
    check('SamplesBuffer uses double', ~contains(src, '''int16''')) ;
    
    src = fileread(fullfile('+ws', 'Logging.m')) ;
    check('Logging stores doubles in HDF5', contains(src, '''double''')) ;
    
    src = fileread(fullfile('+ws', 'Acquisition.m')) ;
    check('Acquisition cache is double', ~contains(src, 'zeros(nScans,nActiveAnalogChannels,''int16'')')) ;
    
    % --- Phase 3: Satellite Elimination ---
    fprintf('\n--- Phase 3: Satellite Elimination ---\n') ;
    
    check('InProcessRunner.m exists', exist('+ws/InProcessRunner.m', 'file') == 2) ;
    
    src = fileread(fullfile('+ws', 'WavesurferModel.m')) ;
    check('WavesurferModel has Runner_', contains(src, 'Runner_')) ;
    check('WavesurferModel no active IPCPublisher_', ...
          ~contains(regexprep(src, '%[^\n]*', ''), 'IPCPublisher_.send')) ;
    check('WavesurferModel no active LooperIPCRequester_', ...
          ~contains(regexprep(src, '%[^\n]*', ''), 'LooperIPCRequester_.send')) ;
    check('WavesurferModel no active RefillerIPCRequester_', ...
          ~contains(regexprep(src, '%[^\n]*', ''), 'RefillerIPCRequester_.send')) ;
    check('WavesurferModel no system() launch', ...
          ~contains(regexprep(src, '%[^\n]*', ''), 'system(looperLaunchString)')) ;
    
    % --- Phase 4: Modern UI ---
    fprintf('\n--- Phase 4: Modern UI ---\n') ;
    
    check('AppFigure.m exists', exist('+ws/AppFigure.m', 'file') == 2) ;
    check('WavesurferMainFigure2.m exists', exist('+ws/WavesurferMainFigure2.m', 'file') == 2) ;
    
    src = fileread(fullfile('+ws', 'AppFigure.m')) ;
    check('AppFigure uses uifigure', contains(src, 'uifigure')) ;
    check('AppFigure uses uigridlayout', contains(src, 'uigridlayout')) ;
    
    src = fileread(fullfile('+ws', 'WavesurferMainFigure2.m')) ;
    check('MainFigure2 uses uiaxes', contains(src, 'uiaxes')) ;
    check('MainFigure2 uses animatedline', contains(src, 'animatedline')) ;
    check('MainFigure2 has merged callbacks', contains(src, 'playButtonPushed_')) ;
    
    % --- Summary ---
    fprintf('\n=== Results: %d passed, %d failed ===\n', nPass, nFail) ;
    
    function check(description, passed)
        if passed
            fprintf('  PASS  %s\n', description) ;
            nPass = nPass + 1 ;
        else
            fprintf('  FAIL  %s\n', description) ;
            nFail = nFail + 1 ;
        end
    end
    
    function result = checkThrows(fn)
        try
            fn() ;
            result = false ;
        catch
            result = true ;
        end
    end
end

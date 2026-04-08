function verifyAllPhases()
    % verifyAllPhases — Comprehensive verification of all modernization changes.
    % Run from the WaveSurfer root directory.
    
    fprintf('=== WaveSurfer Modernization Verification ===\n\n') ;
    nPass = 0 ;
    nFail = 0 ;
    
    % --- Phase 1: Compatibility ---
    fprintf('--- Phase 1: Compatibility ---\n') ;
    v = ws.versionString() ;
    check('Version string updated', contains(v, '1.0.0')) ;
    check('ws.contains raises deprecation', checkThrows(@() ws.contains({'a'}, 'a'))) ;
    
    % --- Phase 2: Hardware Layer ---
    fprintf('\n--- Phase 2: Hardware Layer ---\n') ;
    src = fileread(fullfile('+ws', 'getAllDeviceNamesFromHardware.m')) ;
    check('getAllDeviceNamesFromHardware uses daqlist', contains(src, 'daqlist')) ;
    
    src = fileread(fullfile('+ws', 'AITask.m')) ;
    check('AITask uses daq("ni")', contains(src, 'daq("ni")')) ;
    check('AITask returns doubles', contains(src, 'DOUBLE') || contains(src, 'double')) ;
    
    src = fileread(fullfile('+ws', 'AOTask.m')) ;
    check('AOTask preserves Harnett Cmd I mod', contains(src, 'Cmd I')) ;
    
    src = fileread(fullfile('+ws', 'SamplesBuffer.m')) ;
    check('SamplesBuffer uses double', ~contains(src, '''int16''')) ;
    
    src = fileread(fullfile('+ws', 'Logging.m')) ;
    check('Logging stores doubles in HDF5', contains(src, '''double''')) ;
    
    % --- Phase 3: Satellite Elimination ---
    fprintf('\n--- Phase 3: Satellite Elimination ---\n') ;
    check('InProcessRunner.m exists', exist('+ws/InProcessRunner.m', 'file') == 2) ;
    
    src = fileread(fullfile('+ws', 'WavesurferModel.m')) ;
    check('WavesurferModel has Runner_', contains(src, 'Runner_')) ;
    
    % Strip comments and check for active IPC references
    srcNoComments = regexprep(src, '%[^\n]*', '') ;
    check('No active IPCPublisher_.send', ~contains(srcNoComments, 'IPCPublisher_.send')) ;
    check('No active LooperIPCRequester_', ~contains(srcNoComments, 'LooperIPCRequester_.send')) ;
    check('No active RefillerIPCRequester_', ~contains(srcNoComments, 'RefillerIPCRequester_.send')) ;
    check('No system() satellite launch', ~contains(srcNoComments, 'system(looperLaunchString)')) ;
    
    % GenTL compatibility: untimed DO path
    check('Runner has setUntimedDOState', contains(fileread('+ws/InProcessRunner.m'), 'setUntimedDOState')) ;
    check('WSM routes DO state to Runner', contains(src, 'Runner_.setUntimedDOState')) ;
    
    % User class callback routing
    runnerSrc = fileread(fullfile('+ws', 'InProcessRunner.m')) ;
    check('Runner invokes user samplesAcquired', contains(runnerSrc, 'invokeUserSamplesAcquired_')) ;
    
    % --- Phase 4: Modern UI ---
    fprintf('\n--- Phase 4: Modern UI ---\n') ;
    newFiles = { ...
        'AppFigure', ...
        'WavesurferMainFigure2', ...
        'GeneralSettingsFigure2', ...
        'ChannelsFigure2', ...
        'FastProtocolsFigure2', ...
        'TriggersFigure2', ...
        'ElectrodeManagerFigure2', ...
        'TestPulserFigure2', ...
        'UserCodeManagerFigure2', ...
        'StimulusLibraryFigure2', ...
        'YLimDialogFigure2', ...
        'PlotArrangementDialogFigure2' } ;
    for i = 1:length(newFiles)
        f = newFiles{i} ;
        exists = exist(fullfile('+ws', [f '.m']), 'file') == 2 ;
        check(sprintf('%s.m exists', f), exists) ;
    end
    
    appSrc = fileread(fullfile('+ws', 'AppFigure.m')) ;
    check('AppFigure uses uifigure', contains(appSrc, 'uifigure')) ;
    check('AppFigure uses uigridlayout', contains(appSrc, 'uigridlayout')) ;
    
    mainSrc = fileread(fullfile('+ws', 'WavesurferMainFigure2.m')) ;
    check('MainFigure2 uses uiaxes', contains(mainSrc, 'uiaxes')) ;
    check('MainFigure2 uses animatedline', contains(mainSrc, 'animatedline')) ;
    
    % Launcher update
    launcherSrc = fileread('wavesurfer.m') ;
    check('Launcher uses WavesurferMainFigure2', contains(launcherSrc, 'WavesurferMainFigure2')) ;
    check('Launcher no longer references old controller', ~contains(launcherSrc, 'WavesurferMainController')) ;
    
    % --- Summary ---
    fprintf('\n=== Results: %d passed, %d failed ===\n', nPass, nFail) ;
    if nFail == 0
        fprintf('All checks passed! Ready for hardware testing.\n') ;
    else
        fprintf('Some checks failed — review the FAIL items above.\n') ;
    end
    
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

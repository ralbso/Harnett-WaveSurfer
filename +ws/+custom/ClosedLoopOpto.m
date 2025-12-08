classdef ClosedLoopOpto < ws.UserClass
    
    properties (Constant=true)
        LineIndicator = '  '
        address = '169.254.99.158'
        port = 4545
        
        % Analog Inputs
        voltageChannel = 1;
        
        % Digital Inputs
        screenChannel = 1
%         lickChannel = 2
%         rewardZoneChannel = 4
        
        % Digital Outputs
        LEDChannel = 6
%         valveChannel = 1

        % Plateau detection parameters
        Thresh = -30
        Hyst = 5   % hysteresis (exit at thresh - hyst)
        Tau = 2.0  % Vm time constant (ms) - sets latency
        Slew = 15  % slew limiter (mV/ms)
        MinOn = 5  % min LED ON time
        MinOff = 5 % min LED OFF time
    end
    
    properties
        cameraObj
        TimeAtStartOfLastRunAsString_ = ''  % can't remove
        
        selectedStimulusIndex = 0
        selectedStimulusName = ''
        
        pipette
        sweep
    end
    
    properties (Access=protected, Transient=true)
        % initialize user-settable parameters
        SampleRate_
        
        % camera-related properties
        IsCameraInterfaceInitialized = false
        IsIInFrontend_
        CameraInterface_
        
        % filter params
        A = []  % 1-pole Vm coefficient
        
        PreviousMV = -70  % filtered Vm state (mV)
        LEDOn = 0  % current LED state
        
        SamplesSinceOn = int32(1e9)
        SamplesSinceOff = int32(1e9)
        
        % variables to keep track of
        LastLEDValue_
%         LastRewardZoneValue_
%         Rewarded_
%         LastSampleWasITI_
%         TrialSamples_
%         TimeOfLicks_
%         LastTrialLicks_
%         TrialIndex_
%         TimeOfRewardZoneStart_
%         TimeOfRewardZoneEnd_
%         IsRewardedTrial_
        
        % plotting properties
%         RasterFig_
%         RasterAxes_
    end

    properties (Dependent=true)
        % initialize persistent variables
        SampleRate
    end
    
    methods        
        function self = ClosedLoopOpto()
            % initialize the "user object"
            fprintf("\n%s Loading %s.\n", ...
                    self.LineIndicator, mfilename('class'));
        end
        
        function wake(self, rootModel)  
            % create the "user object"
            % define the default directory to save data to
            rootModel.DataFileLocation = ['D:\ephys\btsp\' datestr(now,'yyyymmdd')];
            if ~exist(rootModel.DataFileLocation, 'dir')
                mkdir(rootModel.DataFileLocation);
            end
            
            % initialize synchronization
            self.synchronizeTransientStateToPersistentStateAndRootModel_(rootModel);
            
            % start new MATLAB instance and create camera object there
            % saves data to the rootModel.DataFileLocation specified above
            system(sprintf('start matlab -nosplash -nodesktop -r "camera = ws.cam.CameraAcquisition(''%s'');"', ...
                rootModel.DataFileLocation));
            
            % define default file base name (prefix 'p')
            rootModel.DataFileBaseName = 'p';
            % include index in base name (suffix)
            rootModel.DoIncludeSessionIndexInDataFileName = 1;
            
            % get next pipette and sweep information
            self.pipette = rootModel.SessionIndex;
            self.sweep = rootModel.NextSweepIndex;
            
            % inform user where and how files will be saved
            fprintf('%s Saving files to %s with prefix %s.\n', self.LineIndicator, ...
                rootModel.DataFileLocation, rootModel.DataFileBaseName);
            
            % check if this is the one true wavesurfer window
            % if so, create a tcp/ip server to interact with the camera
            self.IsIInFrontend_ = (isa(rootModel,'ws.WavesurferModel') && rootModel.IsITheOneTrueWavesurferModel);
            if self.IsIInFrontend_
                if ~self.IsCameraInterfaceInitialized
                    self.CameraInterface_ = ws.cam.CameraInterface(self.address, self.port);
                    self.CameraInterface_.connect;
                    self.IsCameraInterfaceInitialized = true;
                end
            end
        end
        
        function delete(self)
            % Called when there are no more references to the object, just
            % prior to its memory being freed.
            % this method is called by the refiller as well, so anything in
            % here will get executed when the refiller clears its memory
            % between runs
            
            % if figure is open, close it
            if ~isempty(self.RasterFig_)
                if ishghandle(self.RasterFig_)
                    close(self.RasterFig_);
                end
                self.RasterFig_ = [];
            end
        end
        
        %% These methods are called in the frontend process
        function willSaveToProtocolFile(self, wsModel)
            % inform the user about where the protocol will be saved
            fprintf('%s Saving protocol to %s.\n', ...
                    self.LineIndicator, wsModel.AbsoluteProtocolFileName);
        end

        function result = get.SampleRate(self)
            % get the user-defined sample rate
            result = self.SampleRate_;
        end
        
        %% Called every time acq starts or stops/aborts/completes
        function startingRun(self, wsModel)
            % get information on the selected stimulation protocol, and
            % inform the user
            self.selectedStimulusIndex = int32(wsModel.stimulusLibrary.SelectedOutputableIndex);
            self.selectedStimulusName = wsModel.stimulusLibrary.Sequences{self.selectedStimulusIndex}.Name;
            fprintf("%s > Running protocol: %s.\n", self.LineIndicator, self.selectedStimulusName);
            
            % synchronize
            self.synchronizeTransientStateToPersistentStateAndRootModel_(wsModel);
            
            % preset/reset variables to keep track of during a sweep
            self.LastLEDValue_ = 0;
%             self.LastScreenValue_ = 0;
%             self.LastRewardZoneValue_ = 0;
%             self.Rewarded_ = 0;
%             self.LastSampleWasITI_ = 0;
%             self.TrialSamples_ = 0;
%             self.TrialIndex_ = 0;
%             self.LastTrialLicks_ = [];
%             self.TimeOfRewardZoneStart_ = [];
%             self.TimeOfRewardZoneEnd_ = [];
%             self.IsRewardedTrial_ = 0;

            % derive Vm coefficient from tau
            tau = self.Tau / 1000;  % ms -> s
            self.A = exp((1/self.SampleRate_)/tau);
            
            % reset states
            self.PreviousMV = -70;  % filtered Vm state (mV)
            self.LEDOn = 0;         % current LED state

            self.SamplesSinceOn = int32(1e9);
            self.SamplesSinceOff = int32(1e9);
            
            self.pipette = wsModel.SessionIndex;
            self.sweep = wsModel.NextSweepIndex;
            
            % trigger camera after starting recording 
            if self.IsIInFrontend_ && wsModel.IsLoggingEnabled
                try
                    fprintf("\n%s Triggering camera.\n", self.LineIndicator);
                    self.CameraInterface_.startCapture(self.pipette, self.sweep);
                catch
                    fprintf('\n%s There was an error triggering the camera', self.LineIndicator)
                end
            end
        end
        
        function completingRun(self, wsModel)
            % stop camera
            if self.IsIInFrontend_ && wsModel.IsLoggingEnabled
                self.CameraInterface_.stopCapture;
            end
        end
        
        function stoppingRun(self, wsModel)
            % stop camera
            if self.IsIInFrontend_ && wsModel.IsLoggingEnabled
                self.CameraInterface_.stopCapture;
            end
        end        
        
        function abortingRun(self, wsModel)
            % stop camera
            if self.IsIInFrontend_ && wsModel.IsLoggingEnabled
                self.CameraInterface_.stopCapture;
            end
        end
        
        %% Called for each sweep
        % startingSweep, completingSweep, stoppingSweep and abortingSweep
        % have no use when acquiring in Continuous mode
        function startingSweep(self, wsModel)  %#ok<INUSD>
        end
        
        function completingSweep(self, wsModel)  %#ok<INUSD>
        end
        
        function stoppingSweep(self, wsModel)  %#ok<INUSD>
        end        
        
        function abortingSweep(self, wsModel)  %#ok<INUSD>
        end        
        
        % Called each time a "chunk" of data (typically 100 ms worth)
        % has been accumulated from the looper.
        function dataAvailable(self, wsModel)
            % get data
            analogData = wsModel.getLatestAIData();
            digitalData = wsModel.getLatestDIData();
            
            % decode digital inputs
            led = bitget(digitalData, self.ledChannel);
            ledOneSampleInPast = [self.LastLEDValue_; led(1:end-1)];
            
            % analyze voltage signal
            v = analogData(:, self.VoltageChannel);
            dt = 1/self.SampleRate_;
            
        end
        
        %% These methods are called in the looper process
        function samplesAcquired(self, looper, analogData, digitalData)  %#ok<INUSD>
        end
        
        %% These methods are called in the refiller process
        function startingEpisode(self,refiller)  %#ok<INUSD>
        end
        
        function completingEpisode(self,refiller) %#ok<INUSD>
        end
        
        function stoppingEpisode(self,refiller)     %#ok<INUSD>
        end
        
        function abortingEpisode(self,refiller) %#ok<INUSD>
        end
    end  % methods
    
    methods (Access=protected)
        function synchronizeTransientStateToPersistentStateAndRootModel_(self, rootModel)
            if isa(rootModel, 'ws.WavesurferModel')
                self.SampleRate_ = rootModel.AcquisitionSampleRate;
            end
        end
    end
    
    methods
        function result = get(self, propertyName)
            result = self.(propertyName);
        end
        
        function set(self, propertyName, newValue)
            self.(propertyName) = newValue;
        end
    end  % public methods block
    
end  % classdef

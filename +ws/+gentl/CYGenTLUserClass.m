classdef CYGenTLUserClass < ws.UserClass
    
    properties (Constant=true)
        user = 'Courtney'
        LineIndicator = '  '
        address = '169.254.99.158'
        port = 4545
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
        isCameraInterfaceInitialized_ = false
        isIInFrontend_
        cameraInterface_
    end
    
    methods        
        function self = CYGenTLUserClass()
            % creates the "user object"
            fprintf("\n%s Loading preferences.\n", ...
                    self.LineIndicator);
        end
        
        function wake(self, rootModel)  
            % creates the "user object"
            rootModel.DataFileLocation = ['D:\ephys\btsp\' datestr(now,'yyyymmdd')];
            if ~exist(rootModel.DataFileLocation, 'dir')
                mkdir(rootModel.DataFileLocation);
            end
            
            system(sprintf('start matlab -nosplash -r "camera = ws.gentl.CameraAcquisition(''%s'');"', ...
                rootModel.DataFileLocation));
            
            rootModel.DataFileBaseName = 'p';
            rootModel.DoIncludeSessionIndexInDataFileName = 1;
            
            self.pipette = rootModel.SessionIndex;
            self.sweep = rootModel.NextSweepIndex;
            
            fprintf('%s Saving files to %s with prefix %s.\n', self.LineIndicator, ...
                rootModel.DataFileLocation, rootModel.DataFileBaseName);
            
            self.isIInFrontend_ = (isa(rootModel,'ws.WavesurferModel') && rootModel.IsITheOneTrueWavesurferModel);
            if self.isIInFrontend_
                if ~self.isCameraInterfaceInitialized_
                    self.cameraInterface_ = ws.gentl.GenTLCameraInterface(self.address, self.port);
                    self.cameraInterface_.connect;
                    self.isCameraInterfaceInitialized_ = true;
                end
            end
        end
        
        function delete(self)  %#ok<INUSD>
            % Called when there are no more references to the object, just
            % prior to its memory being freed.
            % this method is called by the refiller as well, so anything in
            % here will get executed when the refiller clears its memory
            % between runs
%             fprintf("%s Closing WaveSurfer.\n", self.LineIndicator);
%             fwrite(self.cameraObj, 3);
%             safelyCloseServer_(cameraObj);
        end
        
        %% These methods are called in the frontend process
        function willSaveToProtocolFile(self, wsModel)  
            fprintf('%s Saving protocol to %s.\n', ...
                    self.LineIndicator, wsModel.AbsoluteProtocolFileName);
        end
        
        %% Called every time acq starts or stops/aborts/completes
        function startingRun(self, wsModel)
            self.selectedStimulusIndex = int32(wsModel.stimulusLibrary.SelectedOutputableIndex);
            self.selectedStimulusName = wsModel.stimulusLibrary.Sequences{self.selectedStimulusIndex}.Name;
            fprintf("\n%s Running protocol: %s.", self.LineIndicator, self.selectedStimulusName);
            
            self.pipette = wsModel.SessionIndex;
            self.sweep = wsModel.NextSweepIndex;
            
            if self.isIInFrontend_ && wsModel.IsLoggingEnabled
                try
                    fprintf("\n%s Triggering camera.\n", self.LineIndicator);
                    %s fprintf([num2str(self.pipette) num2str(self.sweep)])
                    self.cameraInterface_.startCapture(self.pipette, self.sweep);
                catch
                    fprintf('\n%s There was an error triggering the camera', self.LineIndicator)
                end
            end
        end
        
        function completingRun(self, wsModel)
            if self.isIInFrontend_ && wsModel.IsLoggingEnabled
                self.cameraInterface_.stopCapture;
            end
        end
        
        function stoppingRun(self, wsModel)
            if self.isIInFrontend_ && wsModel.IsLoggingEnabled
                self.cameraInterface_.stopCapture;
            end
        end        
        
        function abortingRun(self, wsModel)
            if self.isIInFrontend_ && wsModel.IsLoggingEnabled
                self.cameraInterface_.stopCapture;
            end
        end
        
        %% Called for each sweep
        function startingSweep(self, wsModel)  %#ok<INUSD>
        end
        
        function completingSweep(self, wsModel)  %#ok<INUSD>
        end
        
        function stoppingSweep(self, wsModel)  %#ok<INUSD>
        end        
        
        function abortingSweep(self, wsModel)  %#ok<INUSD>
        end        
        
        function dataAvailable(self, wsModel) %#ok<INUSD>
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
    
end  % classdef

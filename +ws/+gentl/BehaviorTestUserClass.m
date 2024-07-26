classdef BehaviorTestUserClass < ws.UserClass
    
    properties (Constant=true)
        LineIndicator = '  '
%         address = '169.254.99.158'
%         port = 4545
        lickChannel = 2
        rewardZoneChannel = 4
        
        valveChannel = 1
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
        IsIInFrontend_
        CameraInterface_
        
        LastRewardZoneValue_
        Rewarded_
    end
    
    methods        
        function self = BehaviorTestUserClass()
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
            
            % start new MATLAB instance and create camera object; saves
            % data to rootModel.DataFileLocation
%             system(sprintf('start matlab -nosplash -r "camera = ws.gentl.CameraAcquisition(''%s'');"', ...
%                 rootModel.DataFileLocation));
            
            rootModel.DataFileBaseName = 'p';
            rootModel.DoIncludeSessionIndexInDataFileName = 1;
            
            self.pipette = rootModel.SessionIndex;
            self.sweep = rootModel.NextSweepIndex;
            
            fprintf('%s Saving files to %s with prefix %s.\n', self.LineIndicator, ...
                rootModel.DataFileLocation, rootModel.DataFileBaseName);
            
%             self.IsIInFrontend_ = (isa(rootModel,'ws.WavesurferModel') && rootModel.IsITheOneTrueWavesurferModel);
%             if self.IsIInFrontend_
%                 if ~self.isCameraInterfaceInitialized_
%                     self.CameraInterface_ = ws.gentl.GenTLCameraInterface(self.address, self.port);
%                     self.CameraInterface_.connect;
%                     self.isCameraInterfaceInitialized_ = true;
%                 end
%             end
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
            fprintf("%s > Running protocol: %s.\n", self.LineIndicator, self.selectedStimulusName);
            
            self.LastRewardZoneValue_ = 0;
            self.Rewarded_ = 0;
            
            self.pipette = wsModel.SessionIndex;
            self.sweep = wsModel.NextSweepIndex;
            
%             if self.IsIInFrontend_ && wsModel.IsLoggingEnabled
%                 try
%                     fprintf("\n%s Triggering camera.\n", self.LineIndicator);
%                     %s fprintf([num2str(self.pipette) num2str(self.sweep)])
%                     self.CameraInterface_.startCapture(self.pipette, self.sweep);
%                 catch
%                     fprintf('\n%s There was an error triggering the camera', self.LineIndicator)
%                 end
%             end
        end
        
        function completingRun(self, wsModel) %#ok<INUSD>
%             if self.IsIInFrontend_ && wsModel.IsLoggingEnabled
%                 self.CameraInterface_.stopCapture;
%             end
        end
        
        function stoppingRun(self, wsModel) %#ok<INUSD>
%             if self.IsIInFrontend_ && wsModel.IsLoggingEnabled
%                 self.CameraInterface_.stopCapture;
%             end
        end        
        
        function abortingRun(self, wsModel) %#ok<INUSD>
%             if self.IsIInFrontend_ && wsModel.IsLoggingEnabled
%                 self.CameraInterface_.stopCapture;
%             end
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
        
        function dataAvailable(self, wsModel)
            % get digital data
            digitalData = wsModel.getLatestDIData();
            licks = bitget(digitalData, self.lickChannel);
            rewardZone = bitget(digitalData, self.rewardZoneChannel);
            
            % did the reward zone end?
            % The falling edge of the reward zone TTL indicates the reward
            % window is over, so we can reset our variables
            rewardZoneOneSampleInPast = [self.LastRewardZoneValue_; rewardZone(1:end-1)];
            isEndOfRewardZone = ~rewardZone & rewardZoneOneSampleInPast;  % find falling edge
            didRewardZoneEnd = isscalar(find(isEndOfRewardZone,1));
            
            % check if any licks occur in the reward zone
            if ~isempty(intersect(find(licks), find(rewardZone))) && ~self.Rewarded_
                % check if valve is off
                if wsModel.DOChannelStateIfUntimed(self.valveChannel) == 0
                    wsModel.DOChannelStateIfUntimed(self.valveChannel) = 1;
                    self.Rewarded_ = 1;
                end
            elseif self.Rewarded_
                wsModel.DOChannelStateIfUntimed(self.valveChannel) = 0;
            end
            
            if didRewardZoneEnd
               self.Rewarded_ = 0;
               
               % make sure the valve is closed if the reward window is over
               wsModel.DOChannelStateIfUntimed(self.valveChannel) = 0;
               
               
            end
            
            % Prepare for next iteration
            self.LastRewardZoneValue_ = rewardZone(end);
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
    
    methods
        function syncRasterFigAndAxes_(self, wsModel)
            if isempty(self.RasterFig_) || ~ishghandle(self.RasterFig_)
                self.RasterFig_ = figure('Name', 'Lick Raster', 'NumberTitle', 'off', 'Units', 'pixels');
                set(self.RasterFig_, 'position', [807 85 542 901]);
            end
            
            clf(self.RasterFig_);
            
            self.RasterAxes_ = subplot(
        end
    end  % methods
    
end  % classdef

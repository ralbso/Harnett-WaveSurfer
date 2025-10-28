classdef GoNoGoGenTLUserClass < ws.UserClass
    
    properties (Constant=true)
        LineIndicator = '  '
        address = '169.254.99.158'
        port = 4545
        
        % DI 
        screenChannel = 1
        lickChannel = 2
        rewardZoneChannel = 4
        distractorChannel = 6
        
        % DO
        valveChannel = 1
        penaltyChannel = 2
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
        SampleRate_
        
        IsCameraInterfaceInitialized = false
        IsIInFrontend_
        CameraInterface_
        
        LastScreenValue_
        LastRewardZoneValue_
        Rewarded_
        LastSampleWasITI_
        TrialSamples_
        TimeOfLicks_
        LastTrialLicks_
        TrialIndex_
        TimeOfRewardZoneStart_
        TimeOfRewardZoneEnd_
        IsRewardedTrial_
        
        RasterFig_
        RasterAxes_
    end

    properties (Dependent=true)
        SampleRate
    end
    
    methods        
        function self = GoNoGoGenTLUserClass()
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

            self.synchronizeTransientStateToPersistentStateAndRootModel_(rootModel);
            
            % start new MATLAB instance and create camera object; saves
            % data to rootModel.DataFileLocation
            system(sprintf('start matlab -nosplash -nodesktop -r "camera = ws.gentl.CameraAcquisition(''%s'');"', ...
                rootModel.DataFileLocation));
            
            rootModel.DataFileBaseName = 'p';
            rootModel.DoIncludeSessionIndexInDataFileName = 1;
            
            self.pipette = rootModel.SessionIndex;
            self.sweep = rootModel.NextSweepIndex;
            
            fprintf('%s Saving files to %s with prefix %s.\n', self.LineIndicator, ...
                rootModel.DataFileLocation, rootModel.DataFileBaseName);
            
            self.IsIInFrontend_ = (isa(rootModel,'ws.WavesurferModel') && rootModel.IsITheOneTrueWavesurferModel);
            if self.IsIInFrontend_
                if ~self.IsCameraInterfaceInitialized
                    self.CameraInterface_ = ws.gentl.GenTLCameraInterface(self.address, self.port);
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

            if ~isempty(self.RasterFig_)
                if ishghandle(self.RasterFig_)
                    close(self.RasterFig_);
                end
                self.RasterFig_ = [];
            end
        end
        
        %% These methods are called in the frontend process
        function willSaveToProtocolFile(self, wsModel)  
            fprintf('%s Saving protocol to %s.\n', ...
                    self.LineIndicator, wsModel.AbsoluteProtocolFileName);
        end

        function result = get.SampleRate(self)
            result = self.SampleRate_;
        end
        
        %% Called every time acq starts or stops/aborts/completes
        function startingRun(self, wsModel)
            self.selectedStimulusIndex = int32(wsModel.stimulusLibrary.SelectedOutputableIndex);
            self.selectedStimulusName = wsModel.stimulusLibrary.Sequences{self.selectedStimulusIndex}.Name;
            fprintf("%s > Running protocol: %s.\n", self.LineIndicator, self.selectedStimulusName);
            
            self.synchronizeTransientStateToPersistentStateAndRootModel_(wsModel);
            
            self.LastScreenValue_ = 0;
            self.LastRewardZoneValue_ = 0;
            self.Rewarded_ = 0;
            self.LastSampleWasITI_ = 0;
            self.TrialSamples_ = 0;
            self.TrialIndex_ = 0;
            self.LastTrialLicks_ = [];
            self.TimeOfRewardZoneStart_ = [];
            self.TimeOfRewardZoneEnd_ = [];
            self.IsRewardedTrial_ = 0;
            
            self.pipette = wsModel.SessionIndex;
            self.sweep = wsModel.NextSweepIndex;
            
            if self.IsIInFrontend_ && wsModel.IsLoggingEnabled
                try
                    fprintf("\n%s Triggering camera.\n", self.LineIndicator);
                    %s fprintf([num2str(self.pipette) num2str(self.sweep)])
                    self.CameraInterface_.startCapture(self.pipette, self.sweep);
                catch
                    fprintf('\n%s There was an error triggering the camera', self.LineIndicator)
                end
            end
        end
        
        function completingRun(self, wsModel)
            if self.IsIInFrontend_ && wsModel.IsLoggingEnabled
                self.CameraInterface_.stopCapture;
            end
        end
        
        function stoppingRun(self, wsModel)
            if self.IsIInFrontend_ && wsModel.IsLoggingEnabled
                self.CameraInterface_.stopCapture;
            end
        end        
        
        function abortingRun(self, wsModel)
            if self.IsIInFrontend_ && wsModel.IsLoggingEnabled
                self.CameraInterface_.stopCapture;
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
        
        function dataAvailable(self, wsModel)
            % Called each time a "chunk" of data (typically 100 ms worth)
            % has been accumulated from the looper.
            
            % get digital data
            digitalData = wsModel.getLatestDIData();
            screen = bitget(digitalData, self.screenChannel);
            licks = bitget(digitalData, self.lickChannel);
            rewardZone = bitget(digitalData, self.rewardZoneChannel);
            isDistractor = bitget(digitalData, self.distractorChannel);
            
            if find(isDistractor)
                isDistractorFlag = 1;
            else
                isDistractorFlag = 0;
            end
            
%             fprintf('\nDistractor: %d', isDistractorFlag)
%             fprintf('Licks + Rew: %d', ~isempty(intersect(find(licks), find(rewardZone))))
            
            % check if any licks occur in the reward zone and open valve
            if ~isempty(intersect(find(licks), find(rewardZone))) && ~isDistractorFlag && ~self.Rewarded_
                % check if valve is off
                if wsModel.DOChannelStateIfUntimed(self.valveChannel) == 0
                    wsModel.DOChannelStateIfUntimed(self.valveChannel) = 1;
                    wsModel.DOChannelStateIfUntimed(self.penaltyChannel) = 0;
                    
                    self.Rewarded_ = 1;
                    self.IsRewardedTrial_ = 1;
                end
                
            elseif ~isempty(intersect(find(licks), find(rewardZone))) && isDistractorFlag
                %disp('Penalized')
                wsModel.DOChannelStateIfUntimed(self.penaltyChannel) = 1;
                
            elseif isempty(intersect(find(licks), find(rewardZone))) && isDistractorFlag
                %disp('Not penalized')
                wsModel.DOChannelStateIfUntimed(self.penaltyChannel) = 0;
                
            elseif self.Rewarded_
                wsModel.DOChannelStateIfUntimed(self.valveChannel) = 0;
%                 wsModel.DOChannelStateIfUntimed(self.penaltyChannel) = 0;
            end
%             
%             if ~isempty(find(rewardZone, 1))
%                 self.IsRewardedTrial_ = 1;
%             end
                        
            % === Check if reward zone ended ===
            % The falling edge of the reward zone TTL indicates the reward
            % window is over, so we can reset our variables
            rewardZoneOneSampleInPast = [self.LastRewardZoneValue_; rewardZone(1:end-1)];

            isStartOfRewardZone = rewardZone & ~rewardZoneOneSampleInPast;
            indexStartOfRewardZone = find(isStartOfRewardZone, 1);
            didRewardZoneStart = isscalar(indexStartOfRewardZone);
            
            isEndOfRewardZone = ~rewardZone & rewardZoneOneSampleInPast;  % find falling edge
            indexEndOfRewardZone = find(isEndOfRewardZone, 1);
            didRewardZoneEnd = isscalar(indexEndOfRewardZone);
            
            if didRewardZoneEnd
               self.Rewarded_ = 0;
               % make sure the valve is closed if the reward window is over
               wsModel.DOChannelStateIfUntimed(self.valveChannel) = 0;
            end
            % === OK ===
            
            % === Check if the trial ended so we can plot it ===
            screenOneSampleInPast = [self.LastScreenValue_; screen(1:end-1)];
            isEndOfTrial = ~screen & ~screenOneSampleInPast;
            
            % get all continuous segments where screen is off
            props = regionprops(isEndOfTrial, 'PixelIdxList');
            candidateSegments = {props.PixelIdxList};
            continuousSegments = find(cellfun(@length, candidateSegments) > 1500);
            isITI = isscalar(continuousSegments);
            % === OK ===
            
            % === Plot licks ===
            % if previous sample was ITI but screen is now on, we've begun
            % a new trial
            numNewSamples = size(digitalData, 1);
            newSamplesArr = (1:numNewSamples)';
%             if self.LastSampleWasITI_ && ~isITI
%                 nLicks = length(self.LastTrialLicks_);
%                 
%                 if self.IsRewardedTrial_
%                     plot(self.RasterAxes_, ...
%                         reshape([repmat(self.TimeOfRewardZoneStart_, 1, 2) nan(1)]', 3*1, 1) ./ self.SampleRate_, ...
%                         reshape([repmat(self.TrialIndex_+0.5, 1, 1) repmat(self.TrialIndex_-0.5, 1, 1) nan(1,1)]', 3*1, 1), ...
%                         'b-');
% 
%                     plot(self.RasterAxes_, ...
%                         reshape([repmat(self.TimeOfRewardZoneEnd_, 1, 2) nan(1)]', 3*1, 1) ./ self.SampleRate_, ...
%                         reshape([repmat(self.TrialIndex_+0.5, 1, 1) repmat(self.TrialIndex_-0.5, 1, 1) nan(1,1)]', 3*1, 1), ...
%                         'b-');
%                     
%                     plot(self.RasterAxes_, ...
%                         reshape([repmat(self.LastTrialLicks_,1,2) nan(nLicks,1)]', 3*nLicks, 1) ./ self.SampleRate_, ...
%                         reshape([repmat(self.TrialIndex_+0.5, nLicks, 1) repmat(self.TrialIndex_-0.5, nLicks, 1) nan(nLicks, 1)]', 3*nLicks, 1), ...
%                         'k-');
%                 else
%                     plot(self.RasterAxes_, ...
%                         reshape([repmat(self.TimeOfRewardZoneStart_, 1, 2) nan(1)]', 3*1, 1) ./ self.SampleRate_, ...
%                         reshape([repmat(self.TrialIndex_+0.5, 1, 1) repmat(self.TrialIndex_-0.5, 1, 1) nan(1,1)]', 3*1, 1), ...
%                         'r-');
% 
%                     plot(self.RasterAxes_, ...
%                         reshape([repmat(self.TimeOfRewardZoneEnd_, 1, 2) nan(1)]', 3*1, 1) ./ self.SampleRate_, ...
%                         reshape([repmat(self.TrialIndex_+0.5, 1, 1) repmat(self.TrialIndex_-0.5, 1, 1) nan(1,1)]', 3*1, 1), ...
%                         'r-');
% %                         reshape([repmat(self.LastTrialLicks_,1,2) nan(nLicks,1)]', 3*nLicks, 1) ./ self.SampleRate_, ...
% %                         reshape([repmat(self.TrialIndex_+0.5, nLicks, 1) repmat(self.TrialIndex_-0.5, nLicks, 1) nan(nLicks, 1)]', 3*nLicks, 1), ...
% %                         'r-');
%                     plot(self.RasterAxes_, ...
%                         reshape([repmat(self.LastTrialLicks_,1,2) nan(nLicks,1)]', 3*nLicks, 1) ./ self.SampleRate_, ...
%                         reshape([repmat(self.TrialIndex_+0.5, nLicks, 1) repmat(self.TrialIndex_-0.5, nLicks, 1) nan(nLicks, 1)]', 3*nLicks, 1), ...
%                         'k-');
%                 end
%                 
%                 set(self.RasterAxes_, 'XLim', [0 18]);
%                 set(self.RasterAxes_, 'YLim', [0.5 self.TrialIndex_+0.5+eps]);
%                 set(self.RasterAxes_, 'YTick', 1:self.TrialIndex_);
%   
%                 % get # of samples collected
%                 self.TrialSamples_ = numNewSamples;
%                 
%                 % timestamp each lick
%                 self.TimeOfLicks_ = newSamplesArr(diff(licks)>0);
%                 self.TrialIndex_ = self.TrialIndex_ + 1;
%                 
%                 % new trial, so reset flag
%                 self.IsRewardedTrial_ = 0;
%                 
%             else
%                 self.TimeOfLicks_ = [self.TimeOfLicks_; self.TrialSamples_ + newSamplesArr(diff(licks)>0)];
%                 self.TrialSamples_ = self.TrialSamples_ + numNewSamples;
%                 
%                 if didRewardZoneStart
%                     self.TimeOfRewardZoneStart_ = self.TrialSamples_ + newSamplesArr(indexStartOfRewardZone);
%                 end
%                 if didRewardZoneEnd
%                     self.TimeOfRewardZoneEnd_ = self.TrialSamples_ + newSamplesArr(indexEndOfRewardZone);
%                 end
%             end
            % === OK ===
            
            % Prepare for next iteration
            self.LastRewardZoneValue_ = rewardZone(end);
            self.LastScreenValue_ = screen(end);
            self.LastSampleWasITI_ = isITI;
            self.LastTrialLicks_ = self.TimeOfLicks_;
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
        function syncRasterFigAndAxes_(self)
            if isempty(self.RasterFig_) || ~ishghandle(self.RasterFig_)
                self.RasterFig_ = figure('Name', 'Lick Raster', 'NumberTitle', 'off', 'Units', 'pixels');
                set(self.RasterFig_, 'position', [0 85 450 400]);
            end
            
            clf(self.RasterFig_);
            
            self.RasterAxes_ = subplot(1, 2, [1 2], 'parent', self.RasterFig_);
            hold(self.RasterAxes_, 'on');
            axis(self.RasterAxes_, 'ij');
            ylabel(self.RasterAxes_, 'trial #');
            title(self.RasterAxes_, 'Licks');
            xlabel(self.RasterAxes_, 'time (s)');
            set(self.RasterAxes_, 'YLim', [0.5 1.5 + eps]);
            set(self.RasterAxes_, 'YTick', 1);
        end
    end  % methods
    
    methods (Access=protected)
        function synchronizeTransientStateToPersistentStateAndRootModel_(self, rootModel)
            if isa(rootModel, 'ws.WavesurferModel')
                self.SampleRate_ = rootModel.AcquisitionSampleRate;
%                 if rootModel.IsITheOneTrueWavesurferModel
%                     self.syncRasterFigAndAxes_;
%                 end
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

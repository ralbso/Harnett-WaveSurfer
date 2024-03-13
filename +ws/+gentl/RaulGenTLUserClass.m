classdef RaulGenTLUserClass < ws.UserClass
    
    properties (Constant=true)
        user = 'Raul'
        LineIndicator = '  '
        address = '169.254.99.158'
        port = 4545
    end
    
    properties
        cameraObj
        TimeAtStartOfLastRunAsString_ = ''  % can't remove
        
        selectedStimulusIndex = 0
        selectedStimulusName = ''        
    end
    
    properties (Access=protected, Transient=true)
        isCameraInterfaceInitialized_ = false
        isIInFrontend_
        cameraInterface_
    end
    
    methods        
        function self = RaulGenTLUserClass()
            % creates the "user object"
            fprintf("%s Loading preferences.\n", ...
                    self.LineIndicator);
        end
        
        function wake(self, rootModel)  
            % creates the "user object"
            rootModel.DataFileLocation = ['D:\ephys\' self.user '\' datestr(now,'yyyymmdd')];
            if ~exist(rootModel.DataFileLocation, 'dir')
                mkdir(rootModel.DataFileLocation);
            end
            
            system(sprintf('start matlab -nosplash -r "camera = ws.gentl.CameraAcquisition(''%s'');"', ...
                rootModel.DataFileLocation));
            
            rootModel.DataFileBaseName = 'p';
            rootModel.DoIncludeSessionIndexInDataFileName = 1;
            
            fprintf('%s Saving files to %s with prefix %s.\n', self.LineIndicator, ...
                rootModel.DataFileLocation, rootModel.DataFileBaseName);
            
            self.isIInFrontend_ = (isa(rootModel,'ws.WavesurferModel') && rootModel.IsITheOneTrueWavesurferModel);
            if self.isIInFrontend_
                if ~self.isCameraInterfaceInitialized_
                    self.cameraInterface_ = ws.gentl.GenTLCameraInterface(self.address, self.port);
                    self.cameraInterface_.connect;
%                     self.cameraObj = self.cameraInterface_.connect();
                    self.isCameraInterfaceInitialized_ = true;
                end
%                 self.cameraObj = establishServer_();
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
            
            if self.isIInFrontend_ && wsModel.IsLoggingEnabled
                try
                    fprintf("\n%s Triggering camera.\n", self.LineIndicator);
                    self.cameraInterface_.startCapture;
    %                 fwrite(self.cameraObj, 1, 'int8');
                catch me
                    fprintf(me)
                end
            end
        end
        
        function completingRun(self, wsModel)
            if self.isIInFrontend_ && wsModel.IsLoggingEnabled
                self.cameraInterface_.stopCapture;
%                 fwrite(self.cameraObj, 2, 'int8');
            end
        end
        
        function stoppingRun(self, wsModel)
            if self.isIInFrontend_ && wsModel.IsLoggingEnabled
                self.cameraInterface_.stopCapture;
%                 fwrite(self.cameraObj, 2, 'int8');
            end
        end        
        
        function abortingRun(self, wsModel)
            if self.isIInFrontend_ && wsModel.IsLoggingEnabled
                self.cameraInterface_.stopCapture;
%                 fwrite(self.cameraObj, 2, 'int8');
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

% function server = establishServer_()
%     [~, hostname] = system('hostname');
%     hostname = string(strtrim(hostname));
%     address = resolvehost(hostname, 'address');
%     server = tcpip(address, 4545, 'NetworkRole', 'server');
% 
%     if strcmp(server.Status, 'closed')
%         fprintf('   Establishing connection to camera');
%         fopen(server);
%         fprintf('   Connection established');
%     else
%         fprintf('   Connection already established');
%     end
% 
% end
% 
% function safelyCloseServer_(server)
%     if server.BytesToOutput == 0
%         fclose(server);
%     else
%         pause(0.05);
%         fclose(server);
%     end
% end

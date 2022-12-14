classdef SimpleUserClass < ws.UserClass
    
    % Information that you want to stick around between calls to the
    % functions below, and want to be settable/gettable from outside the
    % object.
    properties
        LineIndicator = '  ';
        TimeAtStartOfLastRunAsString_ = '';
          % TimeAtStartOfLastRunAsString_ should only be accessed from 
          % the methods below, but making it protected is a pain.
        selectedStimulusIndex = 0;
        selectedStimulusName = '';
    end
    
    methods        
        function self = SimpleUserClass()
            % creates the "user object"
            fprintf("%s Loading preferences.\n", ...
                    self.LineIndicator);    
        end
        
        function wake(self, rootModel)  
            % creates the "user object"
            fprintf("%s Waking preferences.\n", ...
                    self.LineIndicator); 
                
            rootModel.DataFileLocation = ['D:\ephys\Raul\' datestr(now,'yyyymmdd')];
            rootModel.DataFileBaseName = 'p';
                
            rootModel.DoIncludeSessionIndexInDataFileName = 1;
            
            fprintf('%s Saving files to %s with prefix %s.\n', self.LineIndicator, ...
                rootModel.DataFileLocation, rootModel.DataFileBaseName);
            
        end
        
        function delete(self)
            % Called when there are no more references to the object, just
            % prior to its memory being freed.
            fprintf("%s Deleting preferences.\n", ...
                    self.LineIndicator);
        end
        
        % These methods are called in the frontend process
        function willSaveToProtocolFile(self, wsModel)  
            fprintf('%s Saving protocol to %s.\n', ...
                    self.LineIndicator, wsModel.AbsoluteProtocolFileName);
        end
        
        function startingRun(self, wsModel)
            self.selectedStimulusIndex = int32(wsModel.stimulusLibrary.SelectedOutputableIndex);
%             disp(self.selectedStimulusIndex);
            self.selectedStimulusName = wsModel.stimulusLibrary.Sequences{self.selectedStimulusIndex}.Name;
            fprintf("%s Running stimulus: %s.\n", self.LineIndicator, self.selectedStimulusName);
            
            if self.selectedStimulusName ~= "Stim RDK Sequence"
                wsModel.StimulationUsesAcquisitionTrigger = 1;
            end
            
            % start python with RDK in external cmd window
            if self.selectedStimulusName == "Normal RDK Sequence"
                fprintf("%s Starting show_rdk.py on Python.\n", self.LineIndicator, self.selectedStimulusName);
                cd 'C:\Users\vr3\Documents\GitHub\raul-exps'
                system("C:\Users\vr3\miniconda3\envs\psychopy\python.exe C:\Users\vr3\Documents\GitHub\raul-exps\scripts\show_rdk.py &"); 
            end
            
            if self.selectedStimulusName == "Stim RDK Sequence"
                if wsModel.IsStimulationEnabled 
                    fprintf("%s Enabling stimulation.\n", self.LineIndicator);
                    wsModel.IsStimulationEnabled = 1; 
                end
                
                wsModel.StimulationUsesAcquisitionTrigger = 0;
                wsModel.StimulationTriggerIndex = 2;
                fprintf("%s Starting show_rdk_stim.py on Python.\n", self.LineIndicator, self.selectedStimulusName);
                cd 'C:\Users\vr3\Documents\GitHub\raul-exps'
                system("C:\Users\vr3\miniconda3\envs\psychopy\python.exe C:\Users\vr3\Documents\GitHub\raul-exps\scripts\show_rdk_stim.py &")
            end
            
        end
        
        function completingRun(self, wsModel)  %#ok<INUSD>
        end
        
        function stoppingRun(self, wsModel)  %#ok<INUSD>
        end        
        
        function abortingRun(self, wsModel)  %#ok<INUSD>
        end
        
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
        
        % These methods are called in the looper process
        function samplesAcquired(self, looper, analogData, digitalData)  %#ok<INUSD>
        end
        
        % These methods are called in the refiller process
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


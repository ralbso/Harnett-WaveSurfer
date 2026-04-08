classdef GeneralSettingsFigure2 < ws.AppFigure
    % GeneralSettingsFigure2 — Modern uifigure-based General Settings window.
    % Replaces GeneralSettingsFigure (MCOSFigureWithSelfControl).
    % Contains Acquisition, Stimulation, Display, and Logging panels.
    
    properties (Access = protected)
        % Acquisition panel
        AcqPanel_
        SweepModeDropdown_
        SampleRateField_
        NSweepsField_
        SweepDurationField_
        
        % Stimulation panel
        StimPanel_
        StimEnabledCheckbox_
        StimSampleRateField_
        SourceDropdown_
        RepeatsCheckbox_
        
        % Display panel
        DispPanel_
        DispEnabledCheckbox_
        UpdateRateField_
        SpanField_
        AutoSpanCheckbox_
        
        % Logging panel
        LogPanel_
        LocationField_
        ShowLocationButton_
        ChangeLocationButton_
        BaseNameField_
        IncludeDateCheckbox_
        SessionIndexCheckbox_
        SessionIndexField_
        IncrementSessionButton_
        NextSweepField_
        FileNameField_
        OverwriteCheckbox_
    end
    
    methods
        function self = GeneralSettingsFigure2(model)
            self@ws.AppFigure(model, 'General Settings', [520 580]) ;
            
            if ~isempty(model) && isvalid(model)
                model.subscribeMe(self, 'Update', '', 'update') ;
                model.subscribeMe(self, 'DidSetState', '', 'updateControlEnablement') ;
                model.subscribeMe(self, 'DidSetAcquisitionSampleRate', '', 'updateControlProperties') ;
                model.subscribeMe(self, 'DidSetStimulationSampleRate', '', 'updateControlProperties') ;
                model.subscribeMeToDisplayEvent(self, 'Update', '', 'update') ;
                model.subscribeMeToDisplayEvent(self, 'DidSetUpdateRate', '', 'updateControlProperties') ;
                model.subscribeMeToDisplayEvent(self, 'UpdateXSpan', '', 'updateControlProperties') ;
                model.subscribeMeToLoggingEvent(self, 'Update', '', 'updateControlProperties') ;
                model.subscribeMeToLoggingEvent(self, 'UpdateDoIncludeSessionIndex', '', 'update') ;
            end
            
            self.update() ;
            self.show() ;
        end
    end
    
    methods (Access = protected)
        function createComponents_(self)
            self.GridLayout_.RowHeight = {'fit', 'fit', 'fit', '1x'} ;
            self.GridLayout_.ColumnWidth = {'1x'} ;
            self.GridLayout_.Padding = [10 10 10 10] ;
            self.GridLayout_.RowSpacing = 8 ;
            
            self.createAcquisitionPanel_() ;
            self.createStimulationPanel_() ;
            self.createDisplayPanel_() ;
            self.createLoggingPanel_() ;
        end
        
        function createAcquisitionPanel_(self)
            self.AcqPanel_ = uipanel(self.GridLayout_, 'Title', 'Acquisition') ;
            self.AcqPanel_.Layout.Row = 1 ;
            g = uigridlayout(self.AcqPanel_, ...
                'RowHeight', {26, 26, 26}, ...
                'ColumnWidth', {110, '1x', 50}, ...
                'Padding', [8 8 8 4], 'RowSpacing', 4) ;
            
            % Row 1: Sweep mode + Sample rate
            self.SweepModeDropdown_ = uidropdown(g, ...
                'Items', {'Finite', 'Continuous'}, ...
                'ValueChangedFcn', @(~,evt) self.sweepModeChanged_(evt)) ;
            self.SweepModeDropdown_.Layout.Row = 1 ; self.SweepModeDropdown_.Layout.Column = 1 ;
            
            self.SampleRateField_ = uieditfield(g, 'numeric', ...
                'ValueChangedFcn', @(~,evt) self.sampleRateChanged_(evt)) ;
            self.SampleRateField_.Layout.Row = 1 ; self.SampleRateField_.Layout.Column = 2 ;
            uilabel(g, 'Text', 'Hz').Layout.Row = 1 ; uilabel(g, 'Text', 'Hz').Layout.Column = 3 ;
            
            % Row 2: # Sweeps
            uilabel(g, 'Text', '# Sweeps:').Layout.Row = 2 ;
            self.NSweepsField_ = uieditfield(g, 'numeric', ...
                'ValueChangedFcn', @(~,evt) self.nSweepsChanged_(evt)) ;
            self.NSweepsField_.Layout.Row = 2 ; self.NSweepsField_.Layout.Column = 2 ;
            
            % Row 3: Sweep duration
            uilabel(g, 'Text', 'Sweep Duration:').Layout.Row = 3 ;
            self.SweepDurationField_ = uieditfield(g, 'numeric', ...
                'ValueChangedFcn', @(~,evt) self.sweepDurationChanged_(evt)) ;
            self.SweepDurationField_.Layout.Row = 3 ; self.SweepDurationField_.Layout.Column = 2 ;
            uilabel(g, 'Text', 's').Layout.Row = 3 ;
        end
        
        function createStimulationPanel_(self)
            self.StimPanel_ = uipanel(self.GridLayout_, 'Title', 'Stimulation') ;
            self.StimPanel_.Layout.Row = 2 ;
            g = uigridlayout(self.StimPanel_, ...
                'RowHeight', {26, 26, 26}, ...
                'ColumnWidth', {110, '1x', 50}, ...
                'Padding', [8 8 8 4], 'RowSpacing', 4) ;
            
            self.StimEnabledCheckbox_ = uicheckbox(g, 'Text', 'Enabled', ...
                'ValueChangedFcn', @(~,evt) self.stimEnabledChanged_(evt)) ;
            self.StimEnabledCheckbox_.Layout.Row = 1 ; self.StimEnabledCheckbox_.Layout.Column = 1 ;
            
            self.StimSampleRateField_ = uieditfield(g, 'numeric', ...
                'ValueChangedFcn', @(~,evt) self.stimSampleRateChanged_(evt)) ;
            self.StimSampleRateField_.Layout.Row = 1 ; self.StimSampleRateField_.Layout.Column = 2 ;
            uilabel(g, 'Text', 'Hz').Layout.Row = 1 ;
            
            uilabel(g, 'Text', 'Source:').Layout.Row = 2 ;
            self.SourceDropdown_ = uidropdown(g, ...
                'Items', {'(None)'}, ...
                'ValueChangedFcn', @(~,evt) self.sourceChanged_(evt)) ;
            self.SourceDropdown_.Layout.Row = 2 ; self.SourceDropdown_.Layout.Column = [2 3] ;
            
            self.RepeatsCheckbox_ = uicheckbox(g, 'Text', 'Repeat Sequence', ...
                'ValueChangedFcn', @(~,evt) self.repeatsChanged_(evt)) ;
            self.RepeatsCheckbox_.Layout.Row = 3 ; self.RepeatsCheckbox_.Layout.Column = [1 2] ;
        end
        
        function createDisplayPanel_(self)
            self.DispPanel_ = uipanel(self.GridLayout_, 'Title', 'Display') ;
            self.DispPanel_.Layout.Row = 3 ;
            g = uigridlayout(self.DispPanel_, ...
                'RowHeight', {26, 26}, ...
                'ColumnWidth', {110, '1x', 50}, ...
                'Padding', [8 8 8 4], 'RowSpacing', 4) ;
            
            self.DispEnabledCheckbox_ = uicheckbox(g, 'Text', 'Enabled', ...
                'ValueChangedFcn', @(~,evt) self.dispEnabledChanged_(evt)) ;
            self.DispEnabledCheckbox_.Layout.Row = 1 ; self.DispEnabledCheckbox_.Layout.Column = 1 ;
            
            self.UpdateRateField_ = uieditfield(g, 'numeric', ...
                'ValueChangedFcn', @(~,evt) self.updateRateChanged_(evt)) ;
            self.UpdateRateField_.Layout.Row = 1 ; self.UpdateRateField_.Layout.Column = 2 ;
            uilabel(g, 'Text', 'Hz').Layout.Row = 1 ;
            
            uilabel(g, 'Text', 'X Span:').Layout.Row = 2 ;
            self.SpanField_ = uieditfield(g, 'numeric', ...
                'ValueChangedFcn', @(~,evt) self.spanChanged_(evt)) ;
            self.SpanField_.Layout.Row = 2 ; self.SpanField_.Layout.Column = 2 ;
            
            self.AutoSpanCheckbox_ = uicheckbox(g, 'Text', 'Auto', ...
                'ValueChangedFcn', @(~,evt) self.autoSpanChanged_(evt)) ;
            self.AutoSpanCheckbox_.Layout.Row = 2 ; self.AutoSpanCheckbox_.Layout.Column = 3 ;
        end
        
        function createLoggingPanel_(self)
            self.LogPanel_ = uipanel(self.GridLayout_, 'Title', 'Logging') ;
            self.LogPanel_.Layout.Row = 4 ;
            g = uigridlayout(self.LogPanel_, ...
                'RowHeight', {26, 26, 26, 26, 26}, ...
                'ColumnWidth', {80, '1x', 70, 70}, ...
                'Padding', [8 8 8 4], 'RowSpacing', 4) ;
            
            % Row 1: Location
            uilabel(g, 'Text', 'Location:').Layout.Row = 1 ;
            self.LocationField_ = uieditfield(g, ...
                'Editable', 'off') ;
            self.LocationField_.Layout.Row = 1 ; self.LocationField_.Layout.Column = 2 ;
            
            self.ShowLocationButton_ = uibutton(g, 'Text', 'Show', ...
                'ButtonPushedFcn', @(~,~) self.showLocationPushed_()) ;
            self.ShowLocationButton_.Layout.Row = 1 ; self.ShowLocationButton_.Layout.Column = 3 ;
            
            self.ChangeLocationButton_ = uibutton(g, 'Text', 'Change...', ...
                'ButtonPushedFcn', @(~,~) self.changeLocationPushed_()) ;
            self.ChangeLocationButton_.Layout.Row = 1 ; self.ChangeLocationButton_.Layout.Column = 4 ;
            
            % Row 2: Base name
            uilabel(g, 'Text', 'Base Name:').Layout.Row = 2 ;
            self.BaseNameField_ = uieditfield(g, ...
                'ValueChangedFcn', @(~,evt) self.baseNameChanged_(evt)) ;
            self.BaseNameField_.Layout.Row = 2 ; self.BaseNameField_.Layout.Column = [2 4] ;
            
            % Row 3: Include date, session index
            self.IncludeDateCheckbox_ = uicheckbox(g, 'Text', 'Include Date', ...
                'ValueChangedFcn', @(~,evt) self.includeDateChanged_(evt)) ;
            self.IncludeDateCheckbox_.Layout.Row = 3 ; self.IncludeDateCheckbox_.Layout.Column = 1 ;
            
            self.SessionIndexCheckbox_ = uicheckbox(g, 'Text', 'Session Index:', ...
                'ValueChangedFcn', @(~,evt) self.sessionIndexCheckboxChanged_(evt)) ;
            self.SessionIndexCheckbox_.Layout.Row = 3 ; self.SessionIndexCheckbox_.Layout.Column = 2 ;
            
            self.SessionIndexField_ = uieditfield(g, 'numeric', ...
                'ValueChangedFcn', @(~,evt) self.sessionIndexChanged_(evt)) ;
            self.SessionIndexField_.Layout.Row = 3 ; self.SessionIndexField_.Layout.Column = 3 ;
            
            self.IncrementSessionButton_ = uibutton(g, 'Text', '+', ...
                'ButtonPushedFcn', @(~,~) self.incrementSessionPushed_()) ;
            self.IncrementSessionButton_.Layout.Row = 3 ; self.IncrementSessionButton_.Layout.Column = 4 ;
            
            % Row 4: Next sweep
            uilabel(g, 'Text', 'Next Sweep:').Layout.Row = 4 ;
            self.NextSweepField_ = uieditfield(g, 'numeric', ...
                'ValueChangedFcn', @(~,evt) self.nextSweepChanged_(evt)) ;
            self.NextSweepField_.Layout.Row = 4 ; self.NextSweepField_.Layout.Column = 2 ;
            
            self.OverwriteCheckbox_ = uicheckbox(g, 'Text', 'Overwrite', ...
                'ValueChangedFcn', @(~,evt) self.overwriteChanged_(evt)) ;
            self.OverwriteCheckbox_.Layout.Row = 4 ; self.OverwriteCheckbox_.Layout.Column = [3 4] ;
            
            % Row 5: File name preview
            uilabel(g, 'Text', 'File Name:').Layout.Row = 5 ;
            self.FileNameField_ = uieditfield(g, 'Editable', 'off') ;
            self.FileNameField_.Layout.Row = 5 ; self.FileNameField_.Layout.Column = [2 4] ;
        end
        
        % =====================================================================
        % Update implementations
        % =====================================================================
        function updateControlPropertiesImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model)
                return
            end
            
            % Acquisition
            if model.AreSweepsFiniteDuration
                self.SweepModeDropdown_.Value = 'Finite' ;
            else
                self.SweepModeDropdown_.Value = 'Continuous' ;
            end
            self.SampleRateField_.Value = model.AcquisitionSampleRate ;
            self.NSweepsField_.Value = model.NSweepsPerRun ;
            self.SweepDurationField_.Value = model.SweepDuration ;
            
            % Stimulation
            self.StimEnabledCheckbox_.Value = model.IsStimulationEnabled ;
            self.StimSampleRateField_.Value = model.StimulationSampleRate ;
            self.RepeatsCheckbox_.Value = model.DoRepeatStimulusSequence ;
            
            % Update source dropdown with available outputables
            try
                outputableNames = model.getAllOutputableNames() ;
                if isempty(outputableNames)
                    outputableNames = {'(None)'} ;
                end
                self.SourceDropdown_.Items = outputableNames ;
                currentName = model.getCurrentStimulusSequenceName() ;
                if ~isempty(currentName) && any(strcmp(currentName, outputableNames))
                    self.SourceDropdown_.Value = currentName ;
                end
            catch
                self.SourceDropdown_.Items = {'(None)'} ;
            end
            
            % Display
            self.DispEnabledCheckbox_.Value = model.IsDisplayEnabled ;
            self.UpdateRateField_.Value = model.DisplayUpdateRate ;
            self.SpanField_.Value = model.XSpan ;
            self.AutoSpanCheckbox_.Value = model.IsXSpanSlavedToAcquistionDuration ;
            
            % Logging
            self.LocationField_.Value = model.DataFileLocation ;
            self.BaseNameField_.Value = model.DataFileBaseName ;
            self.IncludeDateCheckbox_.Value = model.DoIncludeDate ;
            self.SessionIndexCheckbox_.Value = model.DoIncludeSessionIndex ;
            self.SessionIndexField_.Value = model.SessionIndex ;
            self.NextSweepField_.Value = model.NextSweepIndex ;
            self.OverwriteCheckbox_.Value = model.IsOKToOverwrite ;
            
            % File name preview
            try
                self.FileNameField_.Value = model.NextRunAbsoluteFileName ;
            catch
                self.FileNameField_.Value = '' ;
            end
        end
        
        function updateControlEnablementImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model)
                return
            end
            
            isIdle = isequal(model.State, 'idle') ;
            isStimEnabled = model.IsStimulationEnabled ;
            doIncludeSessionIndex = model.DoIncludeSessionIndex ;
            
            % Acquisition
            self.SweepModeDropdown_.Enable = ws.onIff(isIdle) ;
            self.SampleRateField_.Enable = ws.onIff(isIdle) ;
            self.NSweepsField_.Enable = ws.onIff(isIdle && model.AreSweepsFiniteDuration) ;
            self.SweepDurationField_.Enable = ws.onIff(isIdle && model.AreSweepsFiniteDuration) ;
            
            % Stimulation
            self.StimEnabledCheckbox_.Enable = ws.onIff(isIdle) ;
            self.StimSampleRateField_.Enable = ws.onIff(isIdle && isStimEnabled) ;
            self.SourceDropdown_.Enable = ws.onIff(isIdle && isStimEnabled) ;
            self.RepeatsCheckbox_.Enable = ws.onIff(isIdle && isStimEnabled) ;
            
            % Display
            self.DispEnabledCheckbox_.Enable = ws.onIff(isIdle) ;
            self.SpanField_.Enable = ws.onIff(isIdle && ~model.IsXSpanSlavedToAcquistionDuration) ;
            self.AutoSpanCheckbox_.Enable = ws.onIff(isIdle) ;
            
            % Logging
            self.ChangeLocationButton_.Enable = ws.onIff(isIdle) ;
            self.BaseNameField_.Enable = ws.onIff(isIdle) ;
            self.IncludeDateCheckbox_.Enable = ws.onIff(isIdle) ;
            self.SessionIndexCheckbox_.Enable = ws.onIff(isIdle) ;
            self.SessionIndexField_.Enable = ws.onIff(isIdle && doIncludeSessionIndex) ;
            self.IncrementSessionButton_.Enable = ws.onIff(isIdle && doIncludeSessionIndex) ;
            self.NextSweepField_.Enable = ws.onIff(isIdle) ;
            self.OverwriteCheckbox_.Enable = ws.onIff(isIdle) ;
        end
        
        function closeRequested_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model) || model.isIdleSensuLato()
                self.hide() ;
            end
        end
        
        % =====================================================================
        % Callbacks
        % =====================================================================
        function sweepModeChanged_(self, ~)
            if strcmp(self.SweepModeDropdown_.Value, 'Finite')
                self.Model_.do('set', 'AreSweepsFiniteDuration', true) ;
            else
                self.Model_.do('set', 'AreSweepsFiniteDuration', false) ;
            end
        end
        
        function sampleRateChanged_(self, ~)
            self.Model_.do('set', 'AcquisitionSampleRate', self.SampleRateField_.Value) ;
        end
        
        function nSweepsChanged_(self, ~)
            self.Model_.do('set', 'NSweepsPerRun', round(self.NSweepsField_.Value)) ;
        end
        
        function sweepDurationChanged_(self, ~)
            self.Model_.do('set', 'SweepDuration', self.SweepDurationField_.Value) ;
        end
        
        function stimEnabledChanged_(self, ~)
            self.Model_.do('set', 'IsStimulationEnabled', self.StimEnabledCheckbox_.Value) ;
        end
        
        function stimSampleRateChanged_(self, ~)
            self.Model_.do('set', 'StimulationSampleRate', self.StimSampleRateField_.Value) ;
        end
        
        function sourceChanged_(self, ~)
            self.Model_.do('setCurrentStimulusSequenceByName', self.SourceDropdown_.Value) ;
        end
        
        function repeatsChanged_(self, ~)
            self.Model_.do('set', 'DoRepeatStimulusSequence', self.RepeatsCheckbox_.Value) ;
        end
        
        function dispEnabledChanged_(self, ~)
            self.Model_.do('set', 'IsDisplayEnabled', self.DispEnabledCheckbox_.Value) ;
        end
        
        function updateRateChanged_(self, ~)
            self.Model_.do('set', 'DisplayUpdateRate', self.UpdateRateField_.Value) ;
        end
        
        function spanChanged_(self, ~)
            self.Model_.do('set', 'XSpan', self.SpanField_.Value) ;
        end
        
        function autoSpanChanged_(self, ~)
            self.Model_.do('set', 'IsXSpanSlavedToAcquistionDuration', self.AutoSpanCheckbox_.Value) ;
        end
        
        function showLocationPushed_(self)
            location = self.Model_.DataFileLocation ;
            if ~isempty(location) && exist(location, 'dir')
                if ispc
                    winopen(location) ;
                elseif ismac
                    system(sprintf('open "%s"', location)) ;
                else
                    system(sprintf('xdg-open "%s"', location)) ;
                end
            end
        end
        
        function changeLocationPushed_(self)
            currentLocation = self.Model_.DataFileLocation ;
            newLocation = uigetdir(currentLocation, 'Choose Data File Location') ;
            if ~isequal(newLocation, 0)
                self.Model_.do('set', 'DataFileLocation', newLocation) ;
            end
        end
        
        function baseNameChanged_(self, ~)
            self.Model_.do('set', 'DataFileBaseName', self.BaseNameField_.Value) ;
        end
        
        function includeDateChanged_(self, ~)
            self.Model_.do('set', 'DoIncludeDate', self.IncludeDateCheckbox_.Value) ;
        end
        
        function sessionIndexCheckboxChanged_(self, ~)
            self.Model_.do('set', 'DoIncludeSessionIndex', self.SessionIndexCheckbox_.Value) ;
        end
        
        function sessionIndexChanged_(self, ~)
            self.Model_.do('set', 'SessionIndex', round(self.SessionIndexField_.Value)) ;
        end
        
        function incrementSessionPushed_(self)
            self.Model_.do('incrementSessionIndex') ;
        end
        
        function nextSweepChanged_(self, ~)
            self.Model_.do('set', 'NextSweepIndex', round(self.NextSweepField_.Value)) ;
        end
        
        function overwriteChanged_(self, ~)
            self.Model_.do('set', 'IsOKToOverwrite', self.OverwriteCheckbox_.Value) ;
        end
    end
    
end

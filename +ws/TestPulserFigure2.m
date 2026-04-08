classdef TestPulserFigure2 < ws.AppFigure
    % TestPulserFigure2 — Modern uifigure-based Test Pulse window.
    % Replaces TestPulserFigure + TestPulserController.
    
    properties (Access = protected)
        ScopeAxes_
        TraceLine_
        StartStopButton_
        ElectrodeDropdown_
        AmplitudeField_
        DurationField_
        SubtractBaselineCheckbox_
        AutoYCheckbox_
        AutoYRepeatingCheckbox_
        ResistanceLabel_
    end
    
    methods
        function self = TestPulserFigure2(model)
            self@ws.AppFigure(model, 'Test Pulser', [500 400]) ;
            
            if ~isempty(model) && isvalid(model)
                model.subscribeMe(self, 'Update', '', 'update') ;
                model.subscribeMe(self, 'DidSetState', '', 'updateControlEnablement') ;
                model.subscribeMeToTestPulserEvent(self, 'Update', '', 'update') ;
                model.subscribeMeToTestPulserEvent(self, 'UpdateTrace', '', 'updateTrace') ;
            end
            
            self.update() ;
            self.show() ;
        end
    end
    
    methods (Access = protected)
        function createComponents_(self)
            self.GridLayout_.RowHeight = {'1x', 'fit'} ;
            self.GridLayout_.ColumnWidth = {'1x'} ;
            self.GridLayout_.Padding = [8 8 8 8] ;
            self.GridLayout_.RowSpacing = 6 ;
            
            % Scope area
            self.ScopeAxes_ = uiaxes(self.GridLayout_) ;
            self.ScopeAxes_.Layout.Row = 1 ;
            self.ScopeAxes_.XGrid = 'on' ;
            self.ScopeAxes_.YGrid = 'on' ;
            self.ScopeAxes_.Box = 'on' ;
            self.ScopeAxes_.FontSize = 9 ;
            title(self.ScopeAxes_, '') ;
            xlabel(self.ScopeAxes_, 'Time (ms)') ;
            ylabel(self.ScopeAxes_, '') ;
            self.TraceLine_ = animatedline(self.ScopeAxes_, 'Color', [0.2 0.6 1.0], 'LineWidth', 1) ;
            
            % Controls panel
            controlPanel = uipanel(self.GridLayout_, 'Title', '') ;
            controlPanel.Layout.Row = 2 ;
            cg = uigridlayout(controlPanel, ...
                'RowHeight', {28, 28, 28, 28}, ...
                'ColumnWidth', {100, '1x', 60, 10, 'fit', 'fit'}, ...
                'Padding', [8 8 8 4], 'RowSpacing', 4) ;
            
            % Row 1: Start/Stop + Electrode
            self.StartStopButton_ = uibutton(cg, 'Text', 'Start', ...
                'ButtonPushedFcn', @(~,~) self.startStopPushed_()) ;
            self.StartStopButton_.Layout.Row = 1 ; self.StartStopButton_.Layout.Column = 1 ;
            
            self.ElectrodeDropdown_ = uidropdown(cg, ...
                'Items', {'(None)'}, ...
                'ValueChangedFcn', @(~,~) self.electrodeChanged_()) ;
            self.ElectrodeDropdown_.Layout.Row = 1 ; self.ElectrodeDropdown_.Layout.Column = [2 3] ;
            
            self.ResistanceLabel_ = uilabel(cg, 'Text', '', 'FontWeight', 'bold') ;
            self.ResistanceLabel_.Layout.Row = 1 ; self.ResistanceLabel_.Layout.Column = [5 6] ;
            
            % Row 2: Amplitude
            uilabel(cg, 'Text', 'Amplitude:').Layout.Row = 2 ;
            self.AmplitudeField_ = uieditfield(cg, 'numeric', ...
                'ValueChangedFcn', @(~,~) self.amplitudeChanged_()) ;
            self.AmplitudeField_.Layout.Row = 2 ; self.AmplitudeField_.Layout.Column = 2 ;
            uilabel(cg, 'Text', 'mV').Layout.Row = 2 ;
            
            % Row 3: Duration
            uilabel(cg, 'Text', 'Duration:').Layout.Row = 3 ;
            self.DurationField_ = uieditfield(cg, 'numeric', ...
                'ValueChangedFcn', @(~,~) self.durationChanged_()) ;
            self.DurationField_.Layout.Row = 3 ; self.DurationField_.Layout.Column = 2 ;
            uilabel(cg, 'Text', 'ms').Layout.Row = 3 ;
            
            % Row 4: Checkboxes
            self.SubtractBaselineCheckbox_ = uicheckbox(cg, 'Text', 'Subtract Baseline', ...
                'ValueChangedFcn', @(~,~) self.subtractBaselineChanged_()) ;
            self.SubtractBaselineCheckbox_.Layout.Row = 4 ; self.SubtractBaselineCheckbox_.Layout.Column = [1 2] ;
            
            self.AutoYCheckbox_ = uicheckbox(cg, 'Text', 'Auto Y', ...
                'ValueChangedFcn', @(~,~) self.autoYChanged_()) ;
            self.AutoYCheckbox_.Layout.Row = 4 ; self.AutoYCheckbox_.Layout.Column = 5 ;
            
            self.AutoYRepeatingCheckbox_ = uicheckbox(cg, 'Text', 'Repeat', ...
                'ValueChangedFcn', @(~,~) self.autoYRepeatingChanged_()) ;
            self.AutoYRepeatingCheckbox_.Layout.Row = 4 ; self.AutoYRepeatingCheckbox_.Layout.Column = 6 ;
        end
        
        function updateControlPropertiesImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model), return ; end
            
            % Electrode list
            try
                electrodeNames = model.getAllElectrodeNames() ;
                if isempty(electrodeNames), electrodeNames = {'(None)'} ; end
                self.ElectrodeDropdown_.Items = electrodeNames ;
                currentName = model.getTestPulseElectrodeName() ;
                if ~isempty(currentName) && any(strcmp(currentName, electrodeNames))
                    self.ElectrodeDropdown_.Value = currentName ;
                end
            catch
                self.ElectrodeDropdown_.Items = {'(None)'} ;
            end
            
            % Amplitude, duration
            try
                self.AmplitudeField_.Value = model.TestPulseAmplitude ;
                self.DurationField_.Value = model.TestPulseDuration * 1000 ;  % s -> ms
            catch
            end
            
            % Checkboxes
            try
                self.SubtractBaselineCheckbox_.Value = model.DoSubtractBaselineInTestPulseView ;
                self.AutoYCheckbox_.Value = model.IsAutoYInTestPulseView ;
                self.AutoYRepeatingCheckbox_.Value = model.IsAutoYRepeatingInTestPulseView ;
            catch
            end
            
            % Resistance display
            try
                resistance = model.TestPulseElectrodeResistance ;
                if ~isempty(resistance) && isfinite(resistance)
                    [val, prefix] = ws.convertScalarDimensionalQuantityToEngineering(resistance, 'Ohm') ;
                    self.ResistanceLabel_.Text = sprintf('%.1f %s\x03A9', val, prefix) ;
                else
                    self.ResistanceLabel_.Text = '' ;
                end
            catch
                self.ResistanceLabel_.Text = '' ;
            end
            
            % Start/Stop button text
            try
                if model.IsTestPulsing
                    self.StartStopButton_.Text = 'Stop' ;
                else
                    self.StartStopButton_.Text = 'Start' ;
                end
            catch
            end
        end
        
        function updateControlEnablementImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model), return ; end
            isIdle = isequal(model.State, 'idle') ;
            try
                isTestPulsing = model.IsTestPulsing ;
            catch
                isTestPulsing = false ;
            end
            canStart = isIdle && ~isTestPulsing ;
            self.StartStopButton_.Enable = ws.onIff(isIdle || isTestPulsing) ;
            self.ElectrodeDropdown_.Enable = ws.onIff(canStart) ;
            self.AmplitudeField_.Enable = ws.onIff(canStart) ;
            self.DurationField_.Enable = ws.onIff(canStart) ;
        end
    end
    
    methods
        function updateTrace(self, varargin)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model), return ; end
            try
                [t, y] = model.getTestPulseTraceData() ;
                clearpoints(self.TraceLine_) ;
                if ~isempty(t)
                    addpoints(self.TraceLine_, t * 1000, y) ;  % convert s to ms for display
                end
            catch
            end
        end
    end
    
    methods (Access = protected)
        function startStopPushed_(self)
            try
                if self.Model_.IsTestPulsing
                    self.Model_.do('stopTestPulsing') ;
                else
                    self.Model_.do('startTestPulsing') ;
                end
            catch me
                ws.raiseDialogOnException(me) ;
            end
        end
        
        function electrodeChanged_(self)
            try self.Model_.do('setTestPulseElectrodeByName', self.ElectrodeDropdown_.Value) ;
            catch me, ws.raiseDialogOnException(me) ; end
        end
        function amplitudeChanged_(self)
            try self.Model_.do('set', 'TestPulseAmplitude', self.AmplitudeField_.Value) ;
            catch me, ws.raiseDialogOnException(me) ; end
        end
        function durationChanged_(self)
            try self.Model_.do('set', 'TestPulseDuration', self.DurationField_.Value / 1000) ;  % ms -> s
            catch me, ws.raiseDialogOnException(me) ; end
        end
        function subtractBaselineChanged_(self)
            try self.Model_.do('set', 'DoSubtractBaselineInTestPulseView', self.SubtractBaselineCheckbox_.Value) ;
            catch me, ws.raiseDialogOnException(me) ; end
        end
        function autoYChanged_(self)
            try self.Model_.do('set', 'IsAutoYInTestPulseView', self.AutoYCheckbox_.Value) ;
            catch me, ws.raiseDialogOnException(me) ; end
        end
        function autoYRepeatingChanged_(self)
            try self.Model_.do('set', 'IsAutoYRepeatingInTestPulseView', self.AutoYRepeatingCheckbox_.Value) ;
            catch me, ws.raiseDialogOnException(me) ; end
        end
        
        function closeRequested_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model) || model.isIdleSensuLato()
                self.hide() ;
            end
        end
    end
end

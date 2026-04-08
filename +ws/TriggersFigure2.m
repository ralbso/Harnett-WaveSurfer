classdef TriggersFigure2 < ws.AppFigure
    % TriggersFigure2 — Modern uifigure-based Triggers configuration window.
    % Replaces TriggersFigure + TriggersController.
    
    properties (Access = protected)
        AcqTriggerDropdown_
        StimUsesAcqCheckbox_
        StimTriggerDropdown_
        CounterTriggersTable_
        ExternalTriggersTable_
    end
    
    methods
        function self = TriggersFigure2(model)
            self@ws.AppFigure(model, 'Triggers', [500 380]) ;
            
            if ~isempty(model) && isvalid(model)
                model.subscribeMe(self, 'Update', '', 'update') ;
                model.subscribeMe(self, 'UpdateTriggering', '', 'update') ;
                model.subscribeMe(self, 'DidSetState', '', 'updateControlEnablement') ;
            end
            
            self.update() ;
            self.show() ;
        end
    end
    
    methods (Access = protected)
        function createComponents_(self)
            self.GridLayout_.RowHeight = {'fit', 'fit', '1x', '1x'} ;
            self.GridLayout_.ColumnWidth = {'1x'} ;
            self.GridLayout_.Padding = [10 10 10 10] ;
            self.GridLayout_.RowSpacing = 8 ;
            
            % Acquisition trigger
            acqPanel = uipanel(self.GridLayout_, 'Title', 'Acquisition Trigger') ;
            acqPanel.Layout.Row = 1 ;
            ag = uigridlayout(acqPanel, 'RowHeight', {26}, 'ColumnWidth', {100, '1x'}, ...
                'Padding', [8 8 8 4]) ;
            uilabel(ag, 'Text', 'Source:') ;
            self.AcqTriggerDropdown_ = uidropdown(ag, ...
                'Items', {'Built-in'}, ...
                'ValueChangedFcn', @(~,evt) self.acqTriggerChanged_(evt)) ;
            self.AcqTriggerDropdown_.Layout.Column = 2 ;
            
            % Stimulation trigger
            stimPanel = uipanel(self.GridLayout_, 'Title', 'Stimulation Trigger') ;
            stimPanel.Layout.Row = 2 ;
            sg = uigridlayout(stimPanel, 'RowHeight', {26, 26}, 'ColumnWidth', {160, '1x'}, ...
                'Padding', [8 8 8 4], 'RowSpacing', 4) ;
            self.StimUsesAcqCheckbox_ = uicheckbox(sg, 'Text', 'Use Acquisition Trigger', ...
                'ValueChangedFcn', @(~,evt) self.stimUsesAcqChanged_(evt)) ;
            self.StimUsesAcqCheckbox_.Layout.Column = [1 2] ;
            uilabel(sg, 'Text', 'Source:').Layout.Row = 2 ;
            self.StimTriggerDropdown_ = uidropdown(sg, ...
                'Items', {'Built-in'}, ...
                'ValueChangedFcn', @(~,evt) self.stimTriggerChanged_(evt)) ;
            self.StimTriggerDropdown_.Layout.Row = 2 ; self.StimTriggerDropdown_.Layout.Column = 2 ;
            
            % Counter triggers table
            ctrPanel = uipanel(self.GridLayout_, 'Title', 'Counter Triggers') ;
            ctrPanel.Layout.Row = 3 ;
            cg = uigridlayout(ctrPanel, 'RowHeight', {'1x'}, 'ColumnWidth', {'1x'}, 'Padding', [4 4 4 4]) ;
            self.CounterTriggersTable_ = uitable(cg, ...
                'ColumnName', {'Name', 'Device', 'Counter', 'Repeat Count', 'Interval (s)', 'PFI #', 'Edge'}, ...
                'ColumnEditable', [true false true true true true true]) ;
            
            % External triggers table
            extPanel = uipanel(self.GridLayout_, 'Title', 'External Triggers') ;
            extPanel.Layout.Row = 4 ;
            eg = uigridlayout(extPanel, 'RowHeight', {'1x'}, 'ColumnWidth', {'1x'}, 'Padding', [4 4 4 4]) ;
            self.ExternalTriggersTable_ = uitable(eg, ...
                'ColumnName', {'Name', 'Device', 'PFI #', 'Edge'}, ...
                'ColumnEditable', [true false true true]) ;
        end
        
        function updateControlPropertiesImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model)
                return
            end
            
            % Build trigger source names
            triggerNames = model.getAllTriggerNames() ;
            if isempty(triggerNames)
                triggerNames = {'Built-in'} ;
            end
            
            self.AcqTriggerDropdown_.Items = triggerNames ;
            try
                acqTrigName = model.getAcquisitionTriggerName() ;
                self.AcqTriggerDropdown_.Value = acqTrigName ;
            catch
            end
            
            self.StimUsesAcqCheckbox_.Value = (model.StimulationTriggerIndex == model.AcquisitionTriggerIndex) ;
            
            self.StimTriggerDropdown_.Items = triggerNames ;
            try
                stimTrigName = model.getStimulationTriggerName() ;
                self.StimTriggerDropdown_.Value = stimTrigName ;
            catch
            end
        end
        
        function updateControlEnablementImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model)
                return
            end
            isIdle = isequal(model.State, 'idle') ;
            usesAcq = (model.StimulationTriggerIndex == model.AcquisitionTriggerIndex) ;
            
            self.AcqTriggerDropdown_.Enable = ws.onIff(isIdle) ;
            self.StimUsesAcqCheckbox_.Enable = ws.onIff(isIdle) ;
            self.StimTriggerDropdown_.Enable = ws.onIff(isIdle && ~usesAcq) ;
        end
        
        function acqTriggerChanged_(self, ~)
            try self.Model_.do('setAcquisitionTriggerByName', self.AcqTriggerDropdown_.Value) ;
            catch me, ws.raiseDialogOnException(me) ; end
        end
        
        function stimUsesAcqChanged_(self, ~)
            try
                if self.StimUsesAcqCheckbox_.Value
                    self.Model_.do('set', 'StimulationTriggerIndex', self.Model_.AcquisitionTriggerIndex) ;
                end
            catch me, ws.raiseDialogOnException(me) ; end
        end
        
        function stimTriggerChanged_(self, ~)
            try self.Model_.do('setStimulationTriggerByName', self.StimTriggerDropdown_.Value) ;
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

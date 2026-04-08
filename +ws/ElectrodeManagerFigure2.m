classdef ElectrodeManagerFigure2 < ws.AppFigure
    % ElectrodeManagerFigure2 — Modern uifigure-based Electrode Manager window.
    % Replaces ElectrodeManagerFigure + ElectrodeManagerController.
    % Uses a uitable for all electrode configuration instead of dynamic row controls.
    
    properties (Access = protected)
        ElectrodeTable_
        AddButton_
        RemoveButton_
        UpdateButton_
        SoftpanelButton_
        ReconnectButton_
        DoTrodeUpdateBeforeRunCheckbox_
    end
    
    methods
        function self = ElectrodeManagerFigure2(model)
            self@ws.AppFigure(model, 'Electrode Manager', [700 300]) ;
            
            if ~isempty(model) && isvalid(model)
                model.subscribeMe(self, 'Update', '', 'update') ;
                model.subscribeMe(self, 'UpdateChannels', '', 'update') ;
                model.subscribeMe(self, 'DidSetState', '', 'updateControlEnablement') ;
            end
            
            self.update() ;
            self.show() ;
        end
    end
    
    methods (Access = protected)
        function createComponents_(self)
            self.GridLayout_.RowHeight = {'1x', 32} ;
            self.GridLayout_.ColumnWidth = {'1x'} ;
            self.GridLayout_.Padding = [8 8 8 8] ;
            self.GridLayout_.RowSpacing = 6 ;
            
            % Electrode table
            self.ElectrodeTable_ = uitable(self.GridLayout_, ...
                'ColumnName', {'Label', 'Type', 'Index', 'Mode', 'Monitor Ch', 'Mon Scale', 'Command Ch', 'Cmd Scale', 'Cmd Enabled', 'Remove?'}, ...
                'ColumnFormat', {'char', {'Heka EPC', 'Axon Multiclamp', 'Manual'}, 'numeric', {'VC', 'CC', 'I=0'}, ...
                                 'char', 'numeric', 'char', 'numeric', 'logical', 'logical'}, ...
                'ColumnEditable', [true true true true true true true true true true], ...
                'CellEditCallback', @(src, evt) self.electrodeTableEdited_(evt)) ;
            self.ElectrodeTable_.Layout.Row = 1 ;
            
            % Button bar
            buttonGrid = uigridlayout(self.GridLayout_, ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {60, 70, '1x', 60, 80, 80, 20, 'fit'}, ...
                'Padding', [0 0 0 0], 'ColumnSpacing', 6) ;
            buttonGrid.Layout.Row = 2 ;
            
            self.AddButton_ = uibutton(buttonGrid, 'Text', 'Add', ...
                'ButtonPushedFcn', @(~,~) self.addPushed_()) ;
            self.AddButton_.Layout.Column = 1 ;
            
            self.RemoveButton_ = uibutton(buttonGrid, 'Text', 'Remove', ...
                'ButtonPushedFcn', @(~,~) self.removePushed_()) ;
            self.RemoveButton_.Layout.Column = 2 ;
            
            self.UpdateButton_ = uibutton(buttonGrid, 'Text', 'Update', ...
                'ButtonPushedFcn', @(~,~) self.updatePushed_()) ;
            self.UpdateButton_.Layout.Column = 4 ;
            
            self.SoftpanelButton_ = uibutton(buttonGrid, 'Text', 'Softpanel', ...
                'ButtonPushedFcn', @(~,~) self.softpanelPushed_()) ;
            self.SoftpanelButton_.Layout.Column = 5 ;
            
            self.ReconnectButton_ = uibutton(buttonGrid, 'Text', 'Reconnect', ...
                'ButtonPushedFcn', @(~,~) self.reconnectPushed_()) ;
            self.ReconnectButton_.Layout.Column = 6 ;
            
            self.DoTrodeUpdateBeforeRunCheckbox_ = uicheckbox(buttonGrid, ...
                'Text', 'Update before run', ...
                'ValueChangedFcn', @(~,~) self.doTrodeUpdateChanged_()) ;
            self.DoTrodeUpdateBeforeRunCheckbox_.Layout.Column = 8 ;
        end
        
        function updateControlPropertiesImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model), return ; end
            
            nElectrodes = model.ElectrodeCount ;
            data = cell(nElectrodes, 10) ;
            for i = 1:nElectrodes
                data{i,1} = model.getElectrodeProperty(i, 'Name') ;
                data{i,2} = model.getElectrodeProperty(i, 'Type') ;
                data{i,3} = model.getElectrodeProperty(i, 'IndexWithinType') ;
                data{i,4} = ws.titleStringFromElectrodeMode(model.getElectrodeProperty(i, 'Mode')) ;
                data{i,5} = model.getElectrodeProperty(i, 'MonitorChannelName') ;
                data{i,6} = model.getElectrodeProperty(i, 'MonitorScaling') ;
                data{i,7} = model.getElectrodeProperty(i, 'CommandChannelName') ;
                data{i,8} = model.getElectrodeProperty(i, 'CommandScaling') ;
                data{i,9} = model.getElectrodeProperty(i, 'IsCommandEnabled') ;
                data{i,10} = model.getElectrodeProperty(i, 'IsMarkedForRemoval') ;
            end
            self.ElectrodeTable_.Data = data ;
            self.DoTrodeUpdateBeforeRunCheckbox_.Value = model.DoTrodeUpdateBeforeRun ;
        end
        
        function updateControlEnablementImplementation_(self)
            model = self.Model_ ;
            if isempty(model) || ~isvalid(model), return ; end
            isIdle = isequal(model.State, 'idle') ;
            onOff = ws.onIff(isIdle) ;
            self.ElectrodeTable_.Enable = onOff ;
            self.AddButton_.Enable = onOff ;
            self.RemoveButton_.Enable = onOff ;
            self.UpdateButton_.Enable = onOff ;
            self.DoTrodeUpdateBeforeRunCheckbox_.Enable = onOff ;
        end
        
        function electrodeTableEdited_(self, event) %#ok<INUSD>
            self.update() ;
        end
        
        function addPushed_(self)
            try self.Model_.do('addNewElectrode') ; catch me, ws.raiseDialogOnException(me) ; end
        end
        function removePushed_(self)
            try self.Model_.do('removeMarkedElectrodes') ; catch me, ws.raiseDialogOnException(me) ; end
        end
        function updatePushed_(self)
            try self.Model_.do('updateSmartElectrodeGainsAndModes') ; catch me, ws.raiseDialogOnException(me) ; end
        end
        function softpanelPushed_(self)
            try self.Model_.do('toggleIsInControlOfSoftpanelModeAndGains') ; catch me, ws.raiseDialogOnException(me) ; end
        end
        function reconnectPushed_(self)
            try self.Model_.do('reconnectWithElectrodes') ; catch me, ws.raiseDialogOnException(me) ; end
        end
        function doTrodeUpdateChanged_(self)
            try self.Model_.do('set', 'DoTrodeUpdateBeforeRun', self.DoTrodeUpdateBeforeRunCheckbox_.Value) ;
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

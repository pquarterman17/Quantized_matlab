function saveAsTemplate(appData, fig, setStatus)
%SAVEASTEMPLATE  Save the active dataset's column layout as a template.

    if isempty(appData.datasets) || appData.activeIdx < 1, return; end
    ds = appData.datasets{appData.activeIdx};
    answer = inputdlg('Template name:', 'Save as Template', [1 60], {''});
    if isempty(answer) || isempty(strtrim(answer{1})), return; end

    tmpl = struct();
    tmpl.name = strtrim(answer{1});
    tmpl.type = 'tabular';
    tmpl.match.headerFingerprint = templates.TemplateEngine.fingerprint(ds.data);
    tmpl.match.columnNames = ds.data.labels;
    if isfield(ds.data.metadata, 'parserName')
        tmpl.match.parserName = ds.data.metadata.parserName;
    end
    tmpl.overrides = struct('labels', struct(), 'units', struct());
    templates.TemplateEngine.save(tmpl);
    setStatus(sprintf('Template "%s" saved.', tmpl.name));
end

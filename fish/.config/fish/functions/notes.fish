# Defined in - @ line 1
function notes --wraps='ranger ~/.notes' --description 'alias notes ranger ~/.notes'
  ranger ~/.notes $argv;
end

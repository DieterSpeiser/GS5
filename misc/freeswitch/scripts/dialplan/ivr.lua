-- Gemeinschaft 5 module: ivr class
-- (c) AMOOMA GmbH 2013
-- 

module(...,package.seeall)

Ivr = {}

-- create ivr ivr ;)
function Ivr.new(self, arg)
  arg = arg or {}
  ivr = arg.ivr or {}
  setmetatable(ivr, self);
  self.__index = self;
  self.class = 'ivr';
  self.log = arg.log;
  self.caller = arg.caller;
  self.dtmf_threshold = arg.dtmf_threshold or 500;

  return ivr;
end


function Ivr.ivr_phrase(self, phrase, keys, timeout, ivr_repeat)
  ivr_repeat = ivr_repeat or 3;
  timeout = timeout or 30;
  self.digit = '';
  self.exit = false;

  self.break_keys = {};
  for index=1, #keys do
    self.break_keys[keys[index]] = true;
  end

  global_callback:callback('dtmf', 'ivr_ivr_phrase', self.ivr_phrase_dtmf, self);

  for index=0, ivr_repeat do
    self.caller.session:sayPhrase(phrase, table.concat(keys, ':'));
    self.caller:sleep(timeout * 1000);
    if self.exit then
      break;
    end
  end

  global_callback:callback_unset('dtmf', 'ivr_ivr_phrase');

  return self.digit;
end


function Ivr.ivr_phrase_dtmf(self, dtmf)
  if self.break_keys[dtmf.digit] then
    self.digit = dtmf.digit;
    self.exit = true;
    return false;
  end
end


function Ivr.read_phrase(self, phrase, phrase_data, max_keys, min_keys, timeout, enter_key)
  self.max_keys = max_keys or 64;
  self.min_keys = min_keys or 1;
  self.enter_key = enter_key or '#';
  self.digits = '';
  self.exit = false;
  timeout = timeout or 30;

  global_callback:callback('dtmf', 'ivr_read_phrase', self.read_phrase_dtmf, self);
  self.caller.session:sayPhrase(phrase, phrase_data or enter_key or '');
  self.caller:sleep(timeout * 1000);
  global_callback:callback_unset('dtmf', 'ivr_read_phrase');

  return self.digits;
end


function Ivr.read_phrase_dtmf(self, dtmf)
  if dtmf.duration < self.dtmf_threshold then
    return nil;
  end

  if self.enter_key == dtmf.digit then
    self.exit = true;
    return false;
  end

  self.digits = self.digits .. dtmf.digit;
end


function Ivr.check_pin(self, phrase, pin, pin_timeout, pin_repeat, key_enter)
  if not pin then
    return nil;
  end

  pin_timeout = pin_timeout or 30;
  pin_repeat = pin_repeat or 3;
  key_enter = key_enter or '#';

  local digits = '';
  for i = 1, pin_repeat do
    if digits == pin then
      self.caller:send_display('PIN: OK');
      break
    elseif digits ~= "" then
      self.caller:send_display('PIN: wrong');
    end
    self.caller:send_display('Enter PIN');
    digits = ivr:read_phrase(phrase, nil, 0, pin:len() + 1, pin_timeout, key_enter);
  end

  if digits ~= pin then
    self.caller:send_display('PIN: wrong');
    return false
  end
  self.caller:send_display('PIN: OK');

  return true;
end

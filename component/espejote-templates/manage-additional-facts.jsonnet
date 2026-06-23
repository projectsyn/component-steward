local esp = import 'espejote.libsonnet';

local filterConfigmaps(configmaps) =
  local nameField = function(obj) obj.metadata.name;
  std.filter(
    function(obj) std.objectHas(obj.data, 'spec'),
    std.sort(configmaps, nameField)
  );

local configmaps = filterConfigmaps(esp.context().configmaps);

// Builds a new object from its input.
// All keys which contain an object or array will be suffixed with `+` in the result.
local makeMergeable(o) = {
  [key]+: makeMergeable(o[key])
  for key in std.objectFields(o)
  if std.isObject(o[key])
} + {
  [key]+: o[key]
  for key in std.objectFields(o)
  if std.isArray(o[key])
} + {
  [key]: o[key]
  for key in std.objectFields(o)
  if !std.isObject(o[key]) && !std.isArray(o[key])
};

local targetMetadata(configmaps) =
  local cmNames = std.map(
    function(obj) obj.metadata.name,
    configmaps
  );
  {
    annotations+: {
      'steward.syn.tools/active-configmaps': std.manifestJsonMinified(cmNames),
    },
    labels+: {
      'app.kubernetes.io/managed-by': 'espejote',
    },
  };


[
  kube.Configmap('additional-facts') {
    metadata+: targetMetadata(configmaps),
    data: // todo merge all keys
  },
]

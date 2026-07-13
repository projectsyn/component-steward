local esp = import 'espejote.libsonnet';

local facts = import 'steward-additional-facts/facts.json';
local namespace = import 'steward-additional-facts/namespace.json';

local filterConfigmaps(configmaps) =
  local nameField = function(obj) obj.metadata.name;
  std.filter(
    function(obj) std.objectHas(obj.data, 'facts'),
    std.sort(configmaps, nameField)
  );

local configmapsFacts = filterConfigmaps(esp.context().configmap_facts);

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
    name: 'additional-facts',
    namespace: namespace.name,
  };

local mergeFacts(configmaps, facts) =
  local cmFacts = std.map(
    function(obj) std.parseJson(std.get(obj.data, 'facts', '')),
    configmaps
  );
  std.foldl(
    function(a, b) a + makeMergeable(b),
    cmFacts + [ facts ],
    {}
  );

{
  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: targetMetadata(configmapsFacts),
  data: std.mapWithKey(
    function(_, v) if std.isString(v) then v else std.manifestJsonMinified(v),
    std.prune(mergeFacts(configmapsFacts, facts))
  ),
}

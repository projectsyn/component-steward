local esp = import 'lib/espejote.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();

local params = inv.parameters.steward;

local sa = kube.ServiceAccount('steward-additional-facts-manager') {
  metadata+: {
    namespace: params.namespace,
  },
};

local role = kube.Role('steward:additional-facts-manager') {
  metadata+: {
    namespace: params.namespace,
  },
  rules: [
    {
      apiGroups: [ '' ],
      resources: [ 'configmaps' ],
      verbs: [ 'get', 'list', 'watch' ],
    },
    {
      apiGroups: [ '' ],
      resources: [ 'configmaps' ],
      resourceNames: [ 'additional-facts' ],
      verbs: [ '*' ],
    },
    {
      apiGroups: [ 'espejote.io' ],
      resources: [ 'jsonnetlibraries' ],
      resourceNames: [ 'steward-additional-facts' ],
      verbs: [ 'get', 'list', 'watch' ],
    },
  ],
};

local rolebinding =
  kube.RoleBinding('steward:additional-facts-manager') {
    metadata+: {
      namespace: params.namespace,
    },
    roleRef_: role,
    subjects_: [ sa ],
  };

local jl = esp.jsonnetLibrary('steward-additional-facts', params.namespace) {
  spec: {
    data: {
      'facts.json': std.manifestJson(params.additional_facts),
      'namespace.json': std.manifestJson({ name: params.namespace }),
    },
  },
};

local mr = esp.managedResource('steward-additional-facts', params.namespace) {
  spec: {
    // Set force=true so we can take ownership of previously manually edited
    // fields in `data`.
    applyOptions: { force: true },
    serviceAccountRef: { name: sa.metadata.name },
    context: [
      {
        name: 'configmap_facts',
        resource: {
          apiVersion: 'v1',
          kind: 'ConfigMap',
          labelSelector: {
            matchLabels: {
              [params.additional_facts_config_label]: '',
            },
          },
        },
      },
      {
        name: 'configmap_target',
        resource: {
          apiVersion: 'v1',
          kind: 'ConfigMap',
          name: 'additional-facts',
        },
      },
    ],
    triggers: [
      {
        name: 'jsonnetlib',
        watchResource: {
          apiVersion: jl.apiVersion,
          kind: jl.kind,
          name: jl.metadata.name,
        },
      },
      {
        name: 'configmap_facts',
        watchContextResource: {
          name: 'configmap_facts',
        },
      },
      {
        name: 'configmap_target',
        watchContextResource: {
          name: 'configmap_target',
        },
      },
    ],
    template: importstr 'espejote-templates/manage-additional-facts.jsonnet',
  },
};

[ sa, role, rolebinding, jl, mr ]

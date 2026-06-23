local esp = import 'lib/espejote.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();

local params = inv.parameters.steward;

// Check if espejote is installed and resources are configured
local hasEspejote = std.member(inv.applications, 'espejote');


local sa = kube.ServiceAccount('steward-additional-facts') {
  metadata+: {
    namespace: params.namespace,
  },
};


local clusterrole = kube.ClusterRole('steward:additional-facts') {
  rules: [
    {
      apiGroups: [ '' ],
      resources: [ 'configmaps' ],
      verbs: [ 'get', 'list', 'watch' ],
    },
  ],
};

local clusterrolebinding =
  kube.ClusterRoleBinding('steward:additional-facts') {
    roleRef_: clusterrole,
    subjects_: [ sa ],
  };

local role = kube.Role('steward:additional-facts') {
  metadata+: {
    namespace: params.namespace,
  },
  rules: [
    {
      apiGroups: [ '' ],
      resources: [ 'configmaps' ],
      resourceNames: [ 'additional-facts' ],
      verbs: [ 'get', 'list', 'watch', 'update', 'apply', 'patch' ],
    },
  ],
};

local rolebinding =
  kube.RoleBinding('steward:additional-facts') {
    metadata+: {
      namespace: params.namespace,
    },
    roleRef_: role,
    subjects_: [ sa ],
  };

local mr = esp.managedResource('additional-facts', params.namespace) {
  spec: {
    // Set force=true so we can take ownership of previously manually edited
    // fields in `spec`.
    applyOptions: { force: true },
    serviceAccountRef: { name: sa.metadata.name },
    context: [
      {
        name: 'configmaps',
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
    ],
    triggers: [
      {
        name: 'configmap_config',
        watchContextResource: {
          name: 'configmaps_config',
        },
      },
    ],
    template: importstr 'espejote-templates/manage-additional-facts.jsonnet',
  },
};

local baseAdditionalFacts = kube.ConfigMap('base-additional-facts') {
  metadata+: {
    namespace: params.namespace,
    labels: {
      'app.kubernetes.io/name': 'steward',
      'app.kubernetes.io/managed-by': 'syn',
      [params.additional_facts_config_label]: '',
    },
  },
  data: std.mapWithKey(
    function(_, v)
      if std.isString(v) then v else std.manifestJsonMinified(v),
    std.prune(params.additional_facts)
  ),
};

if hasEspejote then
  [ sa, clusterrole, clusterrolebinding, role, rolebinding, mr, baseAdditionalFacts ]
else [
    kube.ConfigMap('additional-facts') {
    metadata+: {
        namespace: params.namespace,
        labels: {
        'app.kubernetes.io/name': 'steward',
        'app.kubernetes.io/managed-by': 'syn',
        },
    },
    data: std.mapWithKey(
        function(_, v)
        if std.isString(v) then v else std.manifestJsonMinified(v),
        std.prune(params.additional_facts)
    ),
    };
  ],

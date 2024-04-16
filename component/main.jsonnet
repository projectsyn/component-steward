// main template for steward
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.steward;

local cluster_role = kube.ClusterRole('syn-admin') {
  rules: [
    { apiGroups: [ '*' ], resources: [ '*' ], verbs: [ '*' ] },
    { nonResourceURLs: [ '*' ], verbs: [ '*' ] },
  ],
};

local service_account = kube.ServiceAccount('steward') {
  metadata+: {
    namespace: params.namespace,
  },
};

local cluster_role_binding = kube.ClusterRoleBinding('syn-steward') {
  subjects_: [ service_account ],
  roleRef_: cluster_role,
};

local secret = kube.Secret('steward') {
  metadata+: {
    namespace: params.namespace,
  },
  data: {
    token: '',
  },
  stringData: {
    token: params.token,
  },
};

local deployment = kube.Deployment('steward') {
  metadata+: {
    namespace: params.namespace,
    labels: {
      'app.kubernetes.io/name': 'steward',
      'app.kubernetes.io/managed-by': 'syn',
    },
  },
  spec+: {
    template+: {
      spec+: {
        containers_+: {
          steward: kube.Container('steward') {
            image: params.images.steward.image + ':' + params.images.steward.tag,
            imagePullPolicy: 'Always',
            resources: params.resources,
            env_+: com.proxyVars {
              STEWARD_API: params.api_url,
              STEWARD_CLUSTER_ID: inv.parameters.cluster.name,
              STEWARD_TOKEN: kube.SecretKeyRef(secret, 'token'),
              STEWARD_NAMESPACE: kube.FieldRef('metadata.namespace'),
              STEWARD_ARGO_IMAGE: params.images.argocd.image + ':' + params.images.argocd.tag,
            },
            securityContext: {
              runAsNonRoot: true,
            },
          },
        },
        priorityClassName: params.priority_class,
        serviceAccountName: service_account.metadata.name,
      },
    },
  },
};

local additionalFacts = kube.ConfigMap('additional-facts') {
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

{
  '01_rbac': [ cluster_role, service_account, cluster_role_binding ],
  '05_secret': secret,
  '10_deployment': deployment,
  '20_additional_facts': additionalFacts,
}

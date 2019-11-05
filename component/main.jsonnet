// main template for steward
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.steward;

local cluster_role = kube.ClusterRole('syn-admin') {
    rules: [
        { apiGroups: ['*'], resources: ['*'], verbs: ['*'] },
        { nonResourceURLs: ['*'], verbs: ['*'] },
    ],
};

local service_account = kube.ServiceAccount('steward') {
    metadata+: {
        namespace: params.namespace
    },
};

local cluster_role_binding = kube.ClusterRoleBinding('syn-steward') {
    subjects_: [service_account],
    roleRef_: cluster_role,
};

local secret = kube.Secret('steward') {
    metadata+: {
        namespace: params.namespace
    },
    data_: {
        token: params.token
    },
};

local deployment = kube.Deployment('steward') {
    metadata+: {
        namespace: params.namespace
    },
    spec+: {
        template+: {
            spec+: {
                containers_+: {
                    steward: kube.Container('steward') {
                        image: params.images.steward.image + ':' + params.images.steward.tag,
                        imagePullPolicy: 'Always',
                        resources: { 
                            requests: { cpu: '100m', memory: '32Mi' },
                            limits: { cpu: '200m', memory: '64Mi' },
                        },
                        env_+: {
                            'STEWARD_API': params.api_url,
                            'STEWARD_TOKEN': kube.SecretKeyRef(secret, 'token'),
                            'STEWARD_NAMESPACE': kube.FieldRef('metadata.namespace')
                        },
                        securityContext: {
                            runAsNonRoot: true
                        },
                        serviceAccountName: service_account.metadata.name
                    },
                },
            },
        },
    },
};

{
    '00_namespace': kube.Namespace(params.namespace),
    '01_rbac': [cluster_role + service_account + cluster_role_binding],
    '05_secret': secret,
    '10_deployment': deployment,
}

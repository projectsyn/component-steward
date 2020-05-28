local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.steward;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('steward', params.namespace, secrets=true);

{
  steward: app,
}

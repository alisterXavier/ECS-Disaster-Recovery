import boto3
import json
import os

ecs = boto3.client('ecs')

def handler(event, context):
    cluster_arn = os.environ['CLUSTER_ARN']
    desired_count = 3

    ecsClusters = ecs.describe_clusters(
        clusters=[cluster_arn],
        include=[]
    )

    if not ecsClusters['clusters']:
        print('ECS cluster %s not found' % cluster_arn)
        return

    for capacityProvider in ecsClusters['clusters'][0]['capacityProviders']:
        response = ecs.update_capacity_provider(
            name=capacityProvider,
            autoScalingGroupProvider={
                'managedScaling': {
                    'status': 'ENABLED'
                }
            }
        )
        print('Enabled Managed Scaling for capacity provider %s' % (response['capacityProvider']['capacityProviderArn']))

    paginator = ecs.get_paginator('list_services')
    response_iterator = paginator.paginate(
        cluster=cluster_arn,
        launchType='EC2',
        schedulingStrategy='REPLICA'
    )

    for page in response_iterator:
        for service_arn in page['serviceArns']:
            try:
                ecs.update_service(
                    cluster = cluster_arn,
                    service = service_arn,
                    desiredCount=int(desired_count)
                )
            except Exception as e:
                raise Exception('Unable to scale the cluster' + str(e))

            print('Updated service %s desired count to %i' % (service_arn, desired_count))
#!/usr/bin/env python3
"""
MySQL Operator for Kubernetes
Creates Deployment, Service, PV, and PVC for MySQL instances.

CRD: mysqls.otus.homework/v1
"""

import kopf
import kubernetes.client
from kubernetes.client import ApiException
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Constants
CRD_GROUP = "otus.homework"
CRD_VERSION = "v1"
CRD_PLURAL = "mysqls"
STORAGE_CLASS = "local-path"  # Default storage class


def get_api_client():
    """Get Kubernetes API client."""
    config = kopf.OperatorSettings()
    return kubernetes.client.CoreV1Api(), kubernetes.client.AppsV1Api()


def check_resource_exists(api, resource_type, name, namespace=None):
    """Check if a resource already exists."""
    try:
        if resource_type == "pv":
            api.read_persistent_volume(name)
        elif resource_type == "pvc":
            api.read_namespaced_persistent_volume_claim(name, namespace)
        elif resource_type == "service":
            api.read_namespaced_service(name, namespace)
        elif resource_type == "deployment":
            api.read_namespaced_deployment(name, namespace)
        return True
    except ApiException as e:
        if e.status == 404:
            return False
        raise


def create_pv_spec(name, storage_size):
    """Create PersistentVolume specification."""
    return kubernetes.client.V1PersistentVolume(
        api_version="v1",
        kind="PersistentVolume",
        metadata=kubernetes.client.V1ObjectMeta(
            name=name,
            labels={"pv-usage": name},
            finalizers=[]
        ),
        spec=kubernetes.client.V1PersistentVolumeSpec(
            capacity={"storage": storage_size},
            access_modes=["ReadWriteOnce"],
            persistent_volume_reclaim_policy="Retain",
            storage_class_name=STORAGE_CLASS,
            host_path=kubernetes.client.V1HostPathVolumeSource(
                path=f"/tmp/hostpath_pv/{name}/",
                type=""
            )
        )
    )


def create_pvc_spec(pvc_name, pv_name, namespace, storage_size):
    """Create PersistentVolumeClaim specification."""
    return kubernetes.client.V1PersistentVolumeClaim(
        api_version="v1",
        kind="PersistentVolumeClaim",
        metadata=kubernetes.client.V1ObjectMeta(
            name=pvc_name,
            namespace=namespace,
            finalizers=[]
        ),
        spec=kubernetes.client.V1PersistentVolumeClaimSpec(
            access_modes=["ReadWriteOnce"],
            resources=kubernetes.client.V1ResourceRequirements(
                requests={"storage": storage_size}
            ),
            volume_name=pv_name,
            storage_class_name=STORAGE_CLASS
        )
    )


def create_service_spec(name, namespace):
    """Create Service specification."""
    return kubernetes.client.V1Service(
        api_version="v1",
        kind="Service",
        metadata=kubernetes.client.V1ObjectMeta(
            name=name,
            namespace=namespace,
            labels={"app": name}
        ),
        spec=kubernetes.client.V1ServiceSpec(
            type="ClusterIP",
            cluster_ip="None",  # Headless service
            selector={"app": name},
            ports=[
                kubernetes.client.V1ServicePort(
                    port=3306,
                    target_port=3306,
                    protocol="TCP"
                )
            ]
        )
    )


def create_deployment_spec(name, namespace, image, database, password, storage_size):
    """Create Deployment specification."""
    return kubernetes.client.V1Deployment(
        api_version="apps/v1",
        kind="Deployment",
        metadata=kubernetes.client.V1ObjectMeta(
            name=name,
            namespace=namespace,
            labels={"app": name}
        ),
        spec=kubernetes.client.V1DeploymentSpec(
            replicas=1,
            selector=kubernetes.client.V1LabelSelector(
                match_labels={"app": name}
            ),
            template=kubernetes.client.V1PodTemplateSpec(
                metadata=kubernetes.client.V1ObjectMeta(
                    labels={"app": name}
                ),
                spec=kubernetes.client.V1PodSpec(
                    containers=[
                        kubernetes.client.V1Container(
                            name="mysql",
                            image=image,
                            ports=[
                                kubernetes.client.V1ContainerPort(
                                    container_port=3306
                                )
                            ],
                            env=[
                                kubernetes.client.V1EnvVar(
                                    name="MYSQL_ROOT_PASSWORD",
                                    value=password
                                ),
                                kubernetes.client.V1EnvVar(
                                    name="MYSQL_DATABASE",
                                    value=database
                                )
                            ],
                            volume_mounts=[
                                kubernetes.client.V1VolumeMount(
                                    name="data",
                                    mount_path="/var/lib/mysql"
                                )
                            ]
                        )
                    ],
                    volumes=[
                        kubernetes.client.V1Volume(
                            name="data",
                            persistent_volume_claim=kubernetes.client.V1PersistentVolumeClaimVolumeSource(
                                claim_name=f"{name}-pvc"
                            )
                        )
                    ]
                )
            )
        )
    )


@kopf.on.create(CRD_GROUP, CRD_VERSION, CRD_PLURAL)
def mysql_on_create(spec, meta, namespace, name, **kwargs):
    """
    Handle MySQL CR creation.
    Creates: PV, PVC, Service, Deployment
    """
    logger.info(f"Creating MySQL instance: {name} in namespace: {namespace}")

    # Extract parameters from spec
    image = spec.get("image", "mysql:8.0")
    database = spec.get("database", "default_db")
    password = spec.get("password", "default_password")
    storage_size = spec.get("storage_size", "1Gi")

    core_api, apps_api = get_api_client()

    # Resource names
    pv_name = f"{name}-pv"
    pvc_name = f"{name}-pvc"

    # 1. Create PersistentVolume
    if not check_resource_exists(core_api, "pv", pv_name):
        logger.info(f"Creating PersistentVolume: {pv_name}")
        pv = create_pv_spec(pv_name, storage_size)
        try:
            core_api.create_persistent_volume(pv)
            logger.info(f"PersistentVolume {pv_name} created")
        except ApiException as e:
            if e.status != 409:  # Ignore already exists
                raise
    else:
        logger.info(f"PersistentVolume {pv_name} already exists")

    # 2. Create PersistentVolumeClaim
    if not check_resource_exists(core_api, "pvc", pvc_name, namespace):
        logger.info(f"Creating PersistentVolumeClaim: {pvc_name}")
        pvc = create_pvc_spec(pvc_name, pv_name, namespace, storage_size)
        try:
            core_api.create_namespaced_persistent_volume_claim(namespace, pvc)
            logger.info(f"PersistentVolumeClaim {pvc_name} created")
        except ApiException as e:
            if e.status != 409:
                raise
    else:
        logger.info(f"PersistentVolumeClaim {pvc_name} already exists")

    # 3. Create Service
    if not check_resource_exists(core_api, "service", name, namespace):
        logger.info(f"Creating Service: {name}")
        service = create_service_spec(name, namespace)
        try:
            core_api.create_namespaced_service(namespace, service)
            logger.info(f"Service {name} created")
        except ApiException as e:
            if e.status != 409:
                raise
    else:
        logger.info(f"Service {name} already exists")

    # 4. Create Deployment
    if not check_resource_exists(apps_api, "deployment", name, namespace):
        logger.info(f"Creating Deployment: {name}")
        deployment = create_deployment_spec(name, namespace, image, database, password, storage_size)
        try:
            apps_api.create_namespaced_deployment(namespace, deployment)
            logger.info(f"Deployment {name} created")
        except ApiException as e:
            if e.status != 409:
                raise
    else:
        logger.info(f"Deployment {name} already exists")

    logger.info(f"MySQL instance {name} and its children resources created!")

    return {
        "pv": pv_name,
        "pvc": pvc_name,
        "service": name,
        "deployment": name
    }


@kopf.on.delete(CRD_GROUP, CRD_VERSION, CRD_PLURAL)
def mysql_on_delete(spec, meta, namespace, name, **kwargs):
    """
    Handle MySQL CR deletion.
    Deletes: Deployment, Service, PVC, PV
    """
    logger.info(f"Deleting MySQL instance: {name} in namespace: {namespace}")

    core_api, apps_api = get_api_client()

    # Resource names
    pv_name = f"{name}-pv"
    pvc_name = f"{name}-pvc"

    # Delete in reverse order of creation
    # 1. Delete Deployment
    try:
        apps_api.delete_namespaced_deployment(name, namespace)
        logger.info(f"Deployment {name} deleted")
    except ApiException as e:
        if e.status != 404:
            logger.warning(f"Failed to delete deployment: {e}")

    # 2. Delete Service
    try:
        core_api.delete_namespaced_service(name, namespace)
        logger.info(f"Service {name} deleted")
    except ApiException as e:
        if e.status != 404:
            logger.warning(f"Failed to delete service: {e}")

    # 3. Delete PVC
    try:
        core_api.delete_namespaced_persistent_volume_claim(pvc_name, namespace)
        logger.info(f"PersistentVolumeClaim {pvc_name} deleted")
    except ApiException as e:
        if e.status != 404:
            logger.warning(f"Failed to delete PVC: {e}")

    # 4. Delete PV
    try:
        core_api.delete_persistent_volume(pv_name)
        logger.info(f"PersistentVolume {pv_name} deleted")
    except ApiException as e:
        if e.status != 404:
            logger.warning(f"Failed to delete PV: {e}")

    logger.info(f"MySQL instance {name} and its children resources deleted!")


@kopf.on.update(CRD_GROUP, CRD_VERSION, CRD_PLURAL)
def mysql_on_update(spec, old, new, namespace, name, **kwargs):
    """
    Handle MySQL CR update.
    Currently only logs the update, could be extended to handle spec changes.
    """
    logger.info(f"MySQL instance {name} updated")
    logger.info(f"Old spec: {old.get('spec', {})}")
    logger.info(f"New spec: {new.get('spec', {})}")


if __name__ == "__main__":
    kopf.run()
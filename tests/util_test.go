package test

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	a "github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/google/go-github/v53/github"
	aws "github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

func teardown(t *testing.T, directory string, keyPair *aws.Ec2Keypair) {
	err1 := os.RemoveAll(fmt.Sprintf("../examples/%s/rke2", directory))
	require.NoError(t, err1)
	err2 := os.RemoveAll(fmt.Sprintf("../examples/%s/tmp", directory))
	require.NoError(t, err2)
	files, err3 := filepath.Glob(fmt.Sprintf("../examples/%s/.terraform*", directory))
	require.NoError(t, err3)
	for _, f := range files {
		err4 := os.RemoveAll(f)
		require.NoError(t, err4)
	}
	files, err5 := filepath.Glob(fmt.Sprintf("../examples/%s/terraform.*", directory))
	require.NoError(t, err5)
	for _, f := range files {
		err6 := os.Remove(f)
		require.NoError(t, err6)
	}
	files, err7 := filepath.Glob(fmt.Sprintf("../examples/%s/kubeconfig-*", directory))
	require.NoError(t, err7)
	for _, f := range files {
		err8 := os.Remove(f)
		require.NoError(t, err8)
	}

	aws.DeleteEC2KeyPair(t, keyPair)
}

func setup(t *testing.T, directory string, region string, owner string, uniqueID string, terraformVars map[string]interface{}) (*terraform.Options, *aws.Ec2Keypair) {
	// Create an EC2 KeyPair that we can use for SSH access
	if strings.Contains(directory, "_") {
		// because we use the directory name in the ssh key name, we can't allow underscores
		// aws object names must be domain names, and underscores are not allowed in domain names
		err0 := fmt.Errorf("directory name can't contain an underscore")
		require.NoError(t, err0)
	}
	keyPairName := fmt.Sprintf("terraform-aws-rke2-test-%s-%s", directory, uniqueID)
	keyPair := aws.CreateAndImportEC2KeyPair(t, region, keyPairName)

	// tag the key pair so we can find in the access module
	client, err1 := aws.NewEc2ClientE(t, region)
	require.NoError(t, err1)

	input := &ec2.DescribeKeyPairsInput{
		KeyNames: []*string{a.String(keyPairName)},
	}
	result, err2 := client.DescribeKeyPairs(input)
	require.NoError(t, err2)

	aws.AddTagsToResource(t, region, *result.KeyPairs[0].KeyPairId, map[string]string{"Name": keyPairName, "Owner": owner})

	terraformVars["ssh_key_name"] = keyPairName
	terraformVars["identifier"] = uniqueID

	retryableTerraformErrors := map[string]string{
		// The reason is unknown, but eventually these succeed after a few retries.
		".*unable to verify signature.*":             "Failed due to transient network error.",
		".*unable to verify checksum.*":              "Failed due to transient network error.",
		".*no provider exists with the given name.*": "Failed due to transient network error.",
		".*registry service is unreachable.*":        "Failed due to transient network error.",
		".*connection reset by peer.*":               "Failed due to transient network error.",
		".*TLS handshake timeout.*":                  "Failed due to transient network error.",
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: fmt.Sprintf("../examples/%s", directory),
		// Variables to pass to our Terraform code using -var options
		Vars: terraformVars,
		// Environment variables to set when running Terraform
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": region,
		},
		RetryableTerraformErrors: retryableTerraformErrors,
	})
	return terraformOptions, keyPair
}

func getLatestRelease(t *testing.T, owner string, repo string) string {
	ghClient := github.NewClient(nil)
	release, _, err := ghClient.Repositories.GetLatestRelease(context.Background(), owner, repo)
	require.NoError(t, err)
	version := *release.TagName
	return version
}

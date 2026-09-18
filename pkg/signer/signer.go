// Package signer provides access to Argo artifacts stored in S3-compatible
// object storage.
package signer

import (
	"context"
	"fmt"
	"io"
	"net/url"
	"os"
	"strconv"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

const artifactURLLifespan = 10 * time.Minute

// Signer facilitates generating URLs and reading Argo artifacts from an
// S3-compatible object store such as MinIO.
type Signer struct {
	client *minio.Client
}

// NewFromEnv constructs a Signer from MINIO_ENDPOINT, MINIO_ACCESS_KEY,
// MINIO_SECRET_KEY, and the optional MINIO_SECURE and MINIO_REGION variables.
func NewFromEnv() (*Signer, error) {
	endpoint := os.Getenv("MINIO_ENDPOINT")
	accessKey := os.Getenv("MINIO_ACCESS_KEY")
	secretKey := os.Getenv("MINIO_SECRET_KEY")
	if endpoint == "" || accessKey == "" || secretKey == "" {
		return nil, fmt.Errorf("MINIO_ENDPOINT, MINIO_ACCESS_KEY, and MINIO_SECRET_KEY must be set")
	}

	secureValue := os.Getenv("MINIO_SECURE")
	secure := false
	if secureValue != "" {
		var err error
		secure, err = strconv.ParseBool(secureValue)
		if err != nil {
			return nil, fmt.Errorf("invalid MINIO_SECURE value: %w", err)
		}
	}

	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: secure,
		Region: os.Getenv("MINIO_REGION"),
	})
	if err != nil {
		return nil, fmt.Errorf("creating MinIO client: %w", err)
	}

	return &Signer{client: client}, nil
}

// Generate creates a short-lived presigned URL for an Argo artifact.
func (s Signer) Generate(bucket, key string) (string, error) {
	result, err := s.client.PresignedGetObject(context.Background(), bucket, key, artifactURLLifespan, url.Values{})
	if err != nil {
		return "", fmt.Errorf("presigning MinIO artifact %s/%s: %w", bucket, key, err)
	}
	return result.String(), nil
}

// Contents returns the raw contents of an Argo artifact.
func (s Signer) Contents(bucket, key string) ([]byte, error) {
	object, err := s.client.GetObject(context.Background(), bucket, key, minio.GetObjectOptions{})
	if err != nil {
		return nil, fmt.Errorf("opening MinIO artifact %s/%s: %w", bucket, key, err)
	}
	defer object.Close()

	contents, err := io.ReadAll(object)
	if err != nil {
		return nil, fmt.Errorf("reading MinIO artifact %s/%s: %w", bucket, key, err)
	}
	return contents, nil
}


import { DynamoDBClient, PutItemCommand, ScanCommand } from '@aws-sdk/client-dynamodb';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import crypto from 'crypto';

const client = new DynamoDBClient({
  endpoint: process.env.DYNAMODB_ENDPOINT,
});

export const handler = async (event: APIGatewayProxyEventV2, _context: Context) => {
  const tableName = process.env.TABLE_NAME;
  const method = event?.requestContext?.http?.method;

  switch (method) {
    case 'POST': {
      const data = JSON.parse(event.body ?? '{}');
      const item = {
        id: { S: crypto.randomUUID() },
        ...Object.fromEntries(
          Object.entries(data).map(([key, value]) => [key, { S: String(value) }]),
        ),
      };

      await client.send(new PutItemCommand({ TableName: tableName, Item: item }));
      return { statusCode: 200, body: JSON.stringify(unmarshall(item)) };
    }

    case 'GET': {
      const result = await client.send(new ScanCommand({ TableName: tableName }));
      return { statusCode: 200, body: JSON.stringify((result.Items ?? []).map(unmarshall)) };
    }

    default:
      return {
        statusCode: 405,
        body: JSON.stringify({ error: `Method ${method ?? 'undefined'} not allowed` }),
      };
  }
};

const unmarshall = (item: Record<string, any>) => {
  return Object.fromEntries(
    Object.entries(item).map(([key, value]) => [key, value.S]),
  );
};

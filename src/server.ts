import express, {Request, Response} from 'express';
import {existsSync, readFileSync} from "fs";
import {
    BlockAddress,
    Identity,
    IdentityApplicationExtend,
    IdentityMetadata,
    NetworkTypeEnum,
    signData,
    verifyIdentity
} from "@yeying-community/yeying-web3";
import crypto from "crypto";
import {applicationCodeEnumFromJSON, ServiceCodeEnum} from "./yeying/api/common/code";
import path from "path";
import {ApplicationMetadata} from "./yeying/api/common/model";

const workDir = process.cwd()
const identityFile = path.join(workDir, `app.id`)
const passwordFile = process.argv[2]
const port = process.argv.length >= 4 ? <number>(<unknown>process.argv[3]) : 3000

const startServer = async () => {
    if (!existsSync(passwordFile)) {
        throw new Error(`There is no ${passwordFile} password for starting.`)
    }

    const password = readFileSync(passwordFile, 'utf-8')
    if (!existsSync(identityFile)) {
        throw new Error(`There is no ${identityFile} identity for starting.`)
    }

    // 验证身份合法性
    const identity: Identity = Identity.fromJSON(JSON.parse(readFileSync(identityFile, 'utf8')))
    const passed = await verifyIdentity(identity)
    if (!passed) {
        throw new Error(`Invalid identity=${identityFile}`)
    }

    // 解密区块链地址
    const algorithmName = convertToAlgorithmName(identity.securityConfig?.algorithm?.name)
    const cryptoKey = await deriveRawKeyFromString(algorithmName, password)
    const plain = await decrypt(
        algorithmName,
        cryptoKey,
        decodeBase64(identity.securityConfig?.algorithm?.iv as string),
        decodeBase64(identity.blockAddress)
    )
    const blockAddress = BlockAddress.decode(new Uint8Array(plain))

    const applicationMetadata = convertApplicationMetadataFromIdentity(identity)
    applicationMetadata.signature = await signData(blockAddress.privateKey, ApplicationMetadata.encode(applicationMetadata).finish())

    const app = express();
    app.use(express.json());
    // 启用CORS中间件
    app.use((req, res, next) => {
        res.header('Access-Control-Allow-Origin', '*');
        res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
        next();
    });

    app.get('/whoami', (req: Request, res: Response) => {
        res.json(ApplicationMetadata.toJSON(applicationMetadata));
    });

    app.get('/registry', (req: Request, res: Response) => {
        res.json(identity.registry)
    });

    app.listen(port, () => {
        console.log(`Server is running at http://localhost:${port}`);
    });
}

startServer().catch((err) => {
    console.error("Fail to start server", err)
})


export function convertToAlgorithmName(type?: string): string {
    switch (type) {
        case 'CIPHER_TYPE_AES_GCM_256':
            return 'AES-GCM'
        default:
            return 'AES-GCM'
    }
}

export function convertApplicationMetadataFromIdentity(identity: Identity): ApplicationMetadata {
    const metadata = identity.metadata as IdentityMetadata
    const extend = identity.applicationExtend as IdentityApplicationExtend
    return ApplicationMetadata.create({
        owner: metadata.parent,
        network: NetworkTypeEnum[metadata.network],
        address: metadata.address,
        name: metadata.name,
        description: metadata.description,
        did: metadata.did,
        version: metadata.version,
        code: applicationCodeEnumFromJSON(extend.code),
        avatar: metadata.avatar,
        hash: extend.hash,
        location: extend.location,
        createdAt: metadata.createdAt,
        updatedAt: metadata.updatedAt,
        serviceCodes: extend.serviceCodes.split(',').map((a) => ServiceCodeEnum[a as keyof typeof ServiceCodeEnum]),
    })
}

export async function computeHash(content: Uint8Array): Promise<Uint8Array> {
    return new Uint8Array(await crypto.subtle.digest('SHA-256', content))
}

export async function deriveRawKeyFromString(algorithmName: string, content: string): Promise<CryptoKey> {
    const hashBytes = await computeHash(new TextEncoder().encode(content))
    return crypto.subtle.importKey('raw', hashBytes, algorithmName, false, ['encrypt', 'decrypt'])
}

export async function encrypt(
    name: string,
    key: CryptoKey,
    iv: Uint8Array,
    content: Uint8Array | ArrayBuffer
): Promise<ArrayBuffer> {
    return await crypto.subtle.encrypt({name: name, iv: iv}, key, content)
}

export async function decrypt(
    name: string,
    key: CryptoKey,
    iv: Uint8Array,
    content: Uint8Array | ArrayBuffer
): Promise<ArrayBuffer> {
    return await crypto.subtle.decrypt({name: name, iv: iv}, key, content)
}

export function decodeBase64(str: string) {
    return Buffer.from(str, 'base64')
}
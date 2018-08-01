pub struct QueryRoot;

pub struct MutationRoot;

pub type Schema = juniper::RootNode<'static, QueryRoot, MutationRoot>;
